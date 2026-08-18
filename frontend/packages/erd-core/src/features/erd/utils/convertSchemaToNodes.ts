import type { Cardinality, Schema } from '@liam-hq/schema'
import { constraintsToRelationships } from '@liam-hq/schema'
import type { Edge, Node } from '@xyflow/react'
import type { ShowMode } from '../../../schemas/showMode'
import { NON_RELATED_TABLE_GROUP_NODE_ID, zIndex } from '../constants'
import {
  DOMAIN_TAG_PATTERN,
  TABLE_GROUP_NODE_TYPE,
  tableGroupData,
  tableGroupNodeId,
} from '../tableGroups'
import { columnHandleId } from './'

type Params = {
  schema: Schema
  showMode: ShowMode
}

export const convertSchemaToNodes = ({
  schema,
  showMode,
}: Params): {
  nodes: Node[]
  edges: Edge[]
} => {
  const tables = Object.values(schema.tables)
  const relationships = Object.values(constraintsToRelationships(schema.tables))

  const tablesWithRelationships = new Set<string>()
  const sourceColumns = new Map<string, string>()
  const tableColumnCardinalities = new Map<
    string,
    Record<string, Cardinality>
  >()
  for (const relationship of relationships) {
    tablesWithRelationships.add(relationship.primaryTableName)
    tablesWithRelationships.add(relationship.foreignTableName)
    sourceColumns.set(
      relationship.primaryTableName,
      relationship.primaryColumnName,
    )
    tableColumnCardinalities.set(relationship.foreignTableName, {
      ...tableColumnCardinalities.get(relationship.foreignTableName),
      [relationship.foreignColumnName]: relationship.cardinality,
    })
  }

  // QESG custom: assign domain groups from table-comment tags
  const domainOf = new Map<string, string>()
  for (const table of tables) {
    const matched = table.comment?.match(DOMAIN_TAG_PATTERN)
    const domainName = matched?.[1]?.trim()
    if (domainName) {
      domainOf.set(table.name, domainName)
    }
  }
  const domainNames = Array.from(new Set(domainOf.values()))

  // Create table nodes and check if any need NON_RELATED_TABLE_GROUP_NODE_ID as parent
  let hasNonRelatedTables = false
  const tableNodes = tables.map((table) => {
    const domainName = domainOf.get(table.name)
    const isNonRelatedTable =
      !tablesWithRelationships.has(table.name) && domainName === undefined

    if (isNonRelatedTable) {
      hasNonRelatedTables = true
    }

    return {
      id: table.name,
      type: 'table',
      data: {
        table,
        sourceColumnName: sourceColumns.get(table.name),
        targetColumnCardinalities: tableColumnCardinalities.get(table.name),
      },
      position: { x: 0, y: 0 },
      ariaLabel: `${table.name} table`,
      zIndex: zIndex.nodeDefault,
      ...(domainName !== undefined
        ? { parentId: tableGroupNodeId(domainName) }
        : isNonRelatedTable
          ? { parentId: NON_RELATED_TABLE_GROUP_NODE_ID }
          : {}),
    }
  })

  // Domain group nodes must precede their children in the array (React Flow)
  const domainGroupNodes: Node[] = domainNames.map((name) => ({
    id: tableGroupNodeId(name),
    type: TABLE_GROUP_NODE_TYPE,
    data: tableGroupData(name),
    position: { x: 0, y: 0 },
  }))

  // Only include NON_RELATED_TABLE_GROUP_NODE_ID if there are tables that need it
  const nodes: Node[] = [
    ...domainGroupNodes,
    ...(hasNonRelatedTables
      ? [
          {
            id: NON_RELATED_TABLE_GROUP_NODE_ID,
            type: 'nonRelatedTableGroup',
            data: {},
            position: { x: 0, y: 0 },
          },
        ]
      : []),
    ...tableNodes,
  ]

  const edges: Edge[] = relationships.map((rel) => ({
    id: rel.name,
    type: 'relationship',
    source: rel.primaryTableName,
    target: rel.foreignTableName,
    sourceHandle:
      showMode === 'TABLE_NAME'
        ? null
        : columnHandleId(rel.primaryTableName, rel.primaryColumnName),
    targetHandle:
      showMode === 'TABLE_NAME'
        ? null
        : columnHandleId(rel.foreignTableName, rel.foreignColumnName),
    data: {
      relationship: rel,
      cardinality: rel.cardinality,
    },
  }))

  return { nodes, edges }
}
