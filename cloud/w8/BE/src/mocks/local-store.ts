import { randomUUID } from 'crypto';
import { MEDICAL_ENTITIES, MedicalEntityLabel } from '../constants/labels';

export interface LocalDocument {
  id: string;
  title: string;
  category: string;
  text: string;
  status: 'ready_for_review' | 'processing' | 'completed';
  s3Key: string;
  createdAt: string;
}

export interface LocalAnnotation {
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

export function shouldUseLocalFallback() {
  return (
    process.env.NODE_ENV !== 'production' &&
    process.env.DISABLE_LOCAL_MOCKS !== 'true'
  );
}

const sampleDocuments: LocalDocument[] = [
  {
    id: 'doc-001',
    title: 'Cardiac Patient - Visit 2023-10-20',
    category: 'Cardiac',
    status: 'ready_for_review',
    s3Key: 'local/doc-001.txt',
    createdAt: '2026-06-01T08:00:00.000Z',
    text: 'Patient is a 50-year-old female presenting with chest pain radiating to the left arm. History of hypertension and hyperlipidemia. Current medications include atorvastatin 40mg and metoprolol 50mg. ECG shows ST elevation. Plan is to admit to CCU and schedule for urgent cardiac catheterization.',
  },
  {
    id: 'doc-002',
    title: 'Cardiac Patient - Visit 2024-10-10',
    category: 'Cardiac',
    status: 'ready_for_review',
    s3Key: 'local/doc-002.txt',
    createdAt: '2026-06-01T08:05:00.000Z',
    text: 'Patient presents with worsening shortness of breath and pitting edema in both lower extremities. Echocardiogram reveals an ejection fraction of 35%. Patient has a history of congestive heart failure. Added furosemide 40mg daily and advised strict fluid restriction.',
  },
  {
    id: 'doc-003',
    title: 'Cardiac Patient - Visit 2024-06-27',
    category: 'Cardiac',
    status: 'ready_for_review',
    s3Key: 'local/doc-003.txt',
    createdAt: '2026-06-01T08:10:00.000Z',
    text: 'A 64-year-old male reports palpitations and dizziness over the last 48 hours. Holter monitor indicates episodes of atrial fibrillation. Patient is currently taking lisinopril 10mg. Plan to start apixaban 5mg twice daily and consult cardiology.',
  },
];

const localAnnotations: LocalAnnotation[] = [];

const seedSpecs = [
  {
    id: 'local-ann-001',
    documentId: 'doc-001',
    text: 'chest pain',
    label: MEDICAL_ENTITIES.FINDING,
    source: 'llm' as const,
    status: 'suggested' as const,
    confidence: 0.95,
  },
  {
    id: 'local-ann-002',
    documentId: 'doc-001',
    text: 'hypertension',
    label: MEDICAL_ENTITIES.CONDITION,
    source: 'llm' as const,
    status: 'suggested' as const,
    confidence: 0.91,
  },
  {
    id: 'local-ann-003',
    documentId: 'doc-001',
    text: 'atorvastatin 40mg',
    label: MEDICAL_ENTITIES.MEDICATION,
    source: 'llm' as const,
    status: 'accepted' as const,
    confidence: 0.97,
  },
];

for (const spec of seedSpecs) {
  const doc = sampleDocuments.find((item) => item.id === spec.documentId);
  if (!doc) continue;

  const startOffset = doc.text.toLowerCase().indexOf(spec.text.toLowerCase());
  if (startOffset < 0) continue;

  localAnnotations.push({
    annotationId: spec.id,
    documentId: spec.documentId,
    text: doc.text.slice(startOffset, startOffset + spec.text.length),
    label: spec.label,
    startOffset,
    endOffset: startOffset + spec.text.length,
    createdAt: '2026-06-01T08:15:00.000Z',
    source: spec.source,
    status: spec.status,
    confidence: spec.confidence,
  });
}

export function getLocalDocuments() {
  return sampleDocuments.map(({ text, ...document }) => document);
}

export function getLocalDocument(id: string) {
  const document = sampleDocuments.find((item) => item.id === id);
  if (!document) return undefined;

  return {
    ...document,
    annotations: getLocalAnnotationsByDocument(id),
  };
}

export function getLocalAnnotationsByDocument(documentId: string) {
  if (!documentId) return [];

  return localAnnotations
    .filter((annotation) => annotation.documentId === documentId)
    .sort((a, b) => a.startOffset - b.startOffset);
}

export function createLocalAnnotation(
  data: Omit<LocalAnnotation, 'annotationId' | 'createdAt'>,
) {
  const document = sampleDocuments.find((item) => item.id === data.documentId);
  if (!document) {
    throw new Error(`Document with id ${data.documentId} not found`);
  }

  if (data.endOffset > document.text.length) {
    throw new Error('Annotation offsets exceed document length');
  }

  const annotation: LocalAnnotation = {
    ...data,
    annotationId: randomUUID(),
    createdAt: new Date().toISOString(),
  };

  localAnnotations.push(annotation);
  return annotation;
}

export function updateLocalAnnotation(
  annotationId: string,
  updates: Partial<LocalAnnotation>,
) {
  const index = localAnnotations.findIndex(
    (annotation) => annotation.annotationId === annotationId,
  );
  if (index < 0) {
    throw new Error(`Annotation with id ${annotationId} not found`);
  }

  const current = localAnnotations[index];
  localAnnotations[index] = {
    ...current,
    ...updates,
    annotationId: current.annotationId,
    documentId: current.documentId,
  };

  return localAnnotations[index];
}

export function runLocalAnalysis(documentId: string) {
  const document = sampleDocuments.find((item) => item.id === documentId);
  if (!document) {
    throw new Error(`Document with id ${documentId} not found`);
  }

  const candidates = [
    {
      text: 'shortness of breath',
      label: MEDICAL_ENTITIES.FINDING,
      confidence: 0.9,
    },
    {
      text: 'pitting edema',
      label: MEDICAL_ENTITIES.FINDING,
      confidence: 0.86,
    },
    {
      text: 'echocardiogram',
      label: MEDICAL_ENTITIES.PROCEDURE,
      confidence: 0.78,
    },
    {
      text: 'congestive heart failure',
      label: MEDICAL_ENTITIES.CONDITION,
      confidence: 0.92,
    },
    {
      text: 'furosemide 40mg',
      label: MEDICAL_ENTITIES.MEDICATION,
      confidence: 0.95,
    },
    {
      text: 'atrial fibrillation',
      label: MEDICAL_ENTITIES.CONDITION,
      confidence: 0.94,
    },
    {
      text: 'lisinopril 10mg',
      label: MEDICAL_ENTITIES.MEDICATION,
      confidence: 0.97,
    },
    {
      text: 'apixaban 5mg',
      label: MEDICAL_ENTITIES.MEDICATION,
      confidence: 0.96,
    },
    {
      text: 'cardiac catheterization',
      label: MEDICAL_ENTITIES.PROCEDURE,
      confidence: 0.89,
    },
  ];

  for (const candidate of candidates) {
    const startOffset = document.text
      .toLowerCase()
      .indexOf(candidate.text.toLowerCase());
    if (startOffset < 0) continue;

    const alreadyExists = localAnnotations.some(
      (annotation) =>
        annotation.documentId === documentId &&
        annotation.text.toLowerCase() === candidate.text.toLowerCase(),
    );
    if (alreadyExists) continue;

    localAnnotations.push({
      annotationId: randomUUID(),
      documentId,
      text: document.text.slice(startOffset, startOffset + candidate.text.length),
      label: candidate.label,
      startOffset,
      endOffset: startOffset + candidate.text.length,
      createdAt: new Date().toISOString(),
      source: 'llm',
      status: 'suggested',
      confidence: candidate.confidence,
    });
  }
}
