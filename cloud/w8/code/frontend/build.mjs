import { cp, mkdir, rm, copyFile, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(currentDir, '..');
const distPublicDir = path.join(rootDir, 'dist', 'public');
const distPublicAssetsDir = path.join(distPublicDir, 'assets');

await rm(distPublicDir, { recursive: true, force: true });
await mkdir(distPublicAssetsDir, { recursive: true });

await copyFile(
  path.join(currentDir, 'index.html'),
  path.join(distPublicDir, 'index.html'),
);
await copyFile(
  path.join(currentDir, 'styles.css'),
  path.join(distPublicAssetsDir, 'styles.css'),
);
await cp(path.join(currentDir, 'assets'), distPublicAssetsDir, {
  recursive: true,
});

const entryPoint = path.join(currentDir, 'src', 'main.ts');
const compilerOptions = {
  target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.ES2020,
  lib: ['lib.es2020.d.ts', 'lib.dom.d.ts'],
  strict: true,
  skipLibCheck: true,
  noEmit: true,
};

const program = ts.createProgram([entryPoint], compilerOptions);
const diagnostics = ts.getPreEmitDiagnostics(program);

if (diagnostics.length > 0) {
  const host = {
    getCanonicalFileName: (fileName) => fileName,
    getCurrentDirectory: () => rootDir,
    getNewLine: () => '\n',
  };

  console.error(ts.formatDiagnosticsWithColorAndContext(diagnostics, host));
  process.exit(1);
}

const source = await readFile(entryPoint, 'utf8');
const output = ts.transpileModule(source, {
  compilerOptions: {
    target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.ES2020,
    sourceMap: true,
  },
  fileName: entryPoint,
});

await writeFile(path.join(distPublicAssetsDir, 'app.js'), output.outputText);
if (output.sourceMapText) {
  await writeFile(
    path.join(distPublicAssetsDir, 'app.js.map'),
    output.sourceMapText,
  );
}

console.log('Frontend built to dist/public/assets/app.js');
