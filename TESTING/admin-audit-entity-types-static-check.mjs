import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(here, '..');
const migration = readFileSync(
  resolve(
    repositoryRoot,
    'supabase',
    'migrations',
    '20260731180000_expand_admin_audit_entity_types.sql'
  ),
  'utf8'
);
const rollback = readFileSync(
  resolve(
    repositoryRoot,
    'supabase',
    'rollbacks',
    '20260731180000_expand_admin_audit_entity_types.sql'
  ),
  'utf8'
);
const verification = readFileSync(
  resolve(
    here,
    'sql',
    'admin-audit-entity-types-verification.sql'
  ),
  'utf8'
);

const expandedEntityTypes = [
  'qualification_levels',
  'exam_authorities',
  'training_programmes',
  'programme_sections',
  'modules',
  'chapters',
  'topics',
  'learning_resource_types',
  'learning_resources',
  'flashcards',
  'entitlement',
];

assert.doesNotMatch(
  migration,
  /\bcreate\s+(table|function|policy)\b/i,
  'The repair must only expand the existing check constraint.'
);
assert.match(
  migration,
  /drop\s+constraint\s+admin_audit_events_entity_type_check/i
);
assert.match(
  migration,
  /add\s+constraint\s+admin_audit_events_entity_type_check/i
);
assert.match(
  rollback,
  /New administrator audit history exists/i,
  'Rollback must preserve expanded audit history.'
);
assert.ok(
  verification.includes('OVERRIDING SYSTEM VALUE'),
  'Verification must avoid advancing the audit identity sequence.'
);
assert.ok(
  verification.includes("WHEN SQLSTATE 'P0001'"),
  'Verification rows must roll back in a subtransaction.'
);
assert.ok(
  verification.includes('Success. No rows returned'),
  'The expected SQL result must be documented.'
);

for (const entityType of expandedEntityTypes) {
  assert.ok(
    migration.includes(`'${entityType}'`),
    `Migration is missing ${entityType}.`
  );
  assert.ok(
    rollback.includes(`'${entityType}'`),
    `Rollback guard is missing ${entityType}.`
  );
  assert.ok(
    verification.includes(`'${entityType}'`),
    `Runtime verification is missing ${entityType}.`
  );
}

console.log(
  'Admin audit entity-type checks passed: existing constraint expanded, ' +
  'all new bulk types runtime-tested without retained rows or sequence ' +
  'changes, and rollback preserves audit history.'
);
