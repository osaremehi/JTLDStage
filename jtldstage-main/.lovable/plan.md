

## Plan: Simple BYTEA Column Handling to Prevent OOM Crashes

### Problem
When tables contain large binary files (`bytea` columns), the `SELECT *` in `getTableData` loads the entire binary data into memory, causing the edge function to crash with `WORKER_LIMIT`.

### Solution
Before executing the main query, check which columns are `bytea` type. For those columns, replace the value with a size indicator instead of the actual binary data.

---

### Implementation

**File: `supabase/functions/manage-database/index.ts`**

Modify the `getTableData` function (lines 1262-1312):

1. First, query `information_schema.columns` to find which columns are `bytea` type
2. Build a dynamic SELECT that wraps bytea columns in a size indicator
3. Return a list of which columns were replaced (so the UI knows)

#### Before (current code)
```typescript
let query = `SELECT * FROM "${safeSchema}"."${safeTable}"`;
```

#### After (new approach)
```typescript
// Step 1: Get column types
const colTypesResult = await client.queryObject<{
  column_name: string;
  udt_name: string;
}>`
  SELECT column_name, udt_name
  FROM information_schema.columns
  WHERE table_schema = ${schema} AND table_name = ${table}
  ORDER BY ordinal_position
`;

// Step 2: Build SELECT with bytea columns replaced
const byteaColumns: string[] = [];
const selectParts = colTypesResult.rows.map(col => {
  const safeName = `"${col.column_name.replace(/"/g, '""')}"`;
  if (col.udt_name === 'bytea') {
    byteaColumns.push(col.column_name);
    // Return size indicator instead of actual data
    return `CASE 
      WHEN ${safeName} IS NULL THEN NULL
      ELSE '[binary: ' || pg_size_pretty(octet_length(${safeName})::bigint) || ']'
    END AS ${safeName}`;
  }
  return safeName;
});

let query = `SELECT ${selectParts.join(', ')} FROM "${safeSchema}"."${safeTable}"`;
```

---

### Technical Details

| Aspect | Details |
|--------|---------|
| Extra query | One fast metadata query to `information_schema.columns` |
| Output for bytea | `[binary: 15 MB]` or `[binary: 2 kB]` or `NULL` |
| Response addition | Return `byteaColumns: string[]` so frontend knows which columns were replaced |

### Example Output

For a table with columns `id`, `name`, `file_data` (bytea):

| id | name | file_data |
|----|------|-----------|
| 1 | document.pdf | [binary: 2457 kB] |
| 2 | image.png | [binary: 156 kB] |
| 3 | empty | NULL |

---

### Files to Modify

| File | Change |
|------|--------|
| `supabase/functions/manage-database/index.ts` | Update `getTableData` to detect bytea columns and replace with size indicator |

