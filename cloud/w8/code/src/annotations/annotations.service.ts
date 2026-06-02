import { randomUUID } from 'crypto';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  QueryCommand,
  PutCommand,
  UpdateCommand,
  GetCommand,
} from '@aws-sdk/lib-dynamodb';

import { MedicalEntityLabel } from '../constants/labels';
import {
  createLocalAnnotation,
  getLocalAnnotationsByDocument,
  shouldUseLocalFallback,
  updateLocalAnnotation,
} from '../mocks/local-store';

export interface Annotation {
  annotationId: string;
  documentId: string;
  text: string;
  label: MedicalEntityLabel;
  startOffset: number;
  endOffset: number;
  createdAt: string;
  source: 'human' | 'llm';
  status?: 'suggested' | 'accepted' | 'rejected' | 'corrected';
  confidence?: number;
}

export class AnnotationsService {
  private ddbClient: DynamoDBClient;
  private docClient: DynamoDBDocumentClient;

  constructor() {
    this.ddbClient = new DynamoDBClient({});
    this.docClient = DynamoDBDocumentClient.from(this.ddbClient);
  }

  async getAnnotationsByDocument(documentId: string): Promise<Annotation[]> {
    const tableName = process.env.EHR_TABLE_NAME;
    if (!tableName) {
      return getLocalAnnotationsByDocument(documentId) as Annotation[];
    }

    const command = new QueryCommand({
      TableName: tableName,
      KeyConditionExpression: 'PK = :pk AND begins_with(SK, :skPrefix)',
      ExpressionAttributeValues: {
        ':pk': `DOCUMENT#${documentId}`,
        ':skPrefix': 'ANNOTATION#',
      },
    });

    try {
      const response = await this.docClient.send(command);
      return (response.Items as Annotation[]) || [];
    } catch (error) {
      console.error('Error fetching annotations', error);
      return shouldUseLocalFallback()
        ? (getLocalAnnotationsByDocument(documentId) as Annotation[])
        : [];
    }
  }

  async createAnnotation(
    data: Omit<Annotation, 'annotationId' | 'createdAt'>,
  ): Promise<Annotation> {
    const tableName = process.env.EHR_TABLE_NAME;
    if (!tableName) {
      return createLocalAnnotation(data) as Annotation;
    }

    try {
      // Check if document exists in the single table
      const getDocCommand = new GetCommand({
        TableName: tableName,
        Key: {
          PK: `DOCUMENT#${data.documentId}`,
          SK: 'METADATA',
        },
      });
      const docRes = await this.docClient.send(getDocCommand);
      if (!docRes.Item) {
        throw new Error(`Document with id ${data.documentId} not found`);
      }

      const annotationId = randomUUID();
      const newAnnotation: Annotation = {
        ...data,
        annotationId,
        createdAt: new Date().toISOString(),
      };

      const command = new PutCommand({
        TableName: tableName,
        Item: {
          PK: `DOCUMENT#${data.documentId}`,
          SK: `ANNOTATION#${annotationId}`,
          ...newAnnotation,
        },
      });

      await this.docClient.send(command);
      return newAnnotation;
    } catch (error) {
      if (shouldUseLocalFallback()) {
        console.warn('DynamoDB create failed. Using local annotation store.', error);
        return createLocalAnnotation(data) as Annotation;
      }
      throw error;
    }
  }

  async updateAnnotation(
    annotationId: string,
    updates: Partial<Annotation>,
  ): Promise<Annotation> {
    const tableName = process.env.EHR_TABLE_NAME;
    if (!tableName) {
      return updateLocalAnnotation(annotationId, updates) as Annotation;
    }

    // 1. Query the inverted GSI SKIndex to find the composite Key { PK, SK }
    const findCommand = new QueryCommand({
      TableName: tableName,
      IndexName: 'SKIndex',
      KeyConditionExpression: 'SK = :sk',
      ExpressionAttributeValues: {
        ':sk': `ANNOTATION#${annotationId}`,
      },
    });

    try {
      const findResponse = await this.docClient.send(findCommand);
      const item = findResponse.Items?.[0];
      if (!item) {
        throw new Error(`Annotation with id ${annotationId} not found`);
      }
      const PK = item.PK;
      const SK = item.SK;

      // 2. Perform the update
      const updateExpressions: string[] = [];
      const expressionAttributeNames: Record<string, string> = {};
      const expressionAttributeValues: Record<string, any> = {};

      for (const [key, value] of Object.entries(updates)) {
        if (key !== 'annotationId' && key !== 'documentId' && key !== 'PK' && key !== 'SK') {
          updateExpressions.push(`#${key} = :${key}`);
          expressionAttributeNames[`#${key}`] = key;
          expressionAttributeValues[`:${key}`] = value;
        }
      }

      if (updateExpressions.length === 0) {
        return item as Annotation;
      }

      const command = new UpdateCommand({
        TableName: tableName,
        Key: { PK, SK },
        UpdateExpression: `SET ${updateExpressions.join(', ')}`,
        ExpressionAttributeNames: expressionAttributeNames,
        ExpressionAttributeValues: expressionAttributeValues,
        ReturnValues: 'ALL_NEW',
      });

      const response = await this.docClient.send(command);
      return response.Attributes as Annotation;
    } catch (error) {
      if (shouldUseLocalFallback()) {
        console.warn('DynamoDB update failed. Using local annotation store.', error);
        return updateLocalAnnotation(annotationId, updates) as Annotation;
      }
      console.error('Error updating annotation', error);
      throw new Error(`Annotation with id ${annotationId} not found`);
    }
  }
}
