import type { Node, NodeProps } from '@xyflow/react'
import type { FC } from 'react'
import type { TableGroupNodeData } from '../../../../tableGroups'
import styles from './TableGroupNode.module.css'

type TableGroupNodeType = Node<TableGroupNodeData, 'tableGroup'>

type Props = NodeProps<TableGroupNodeType>

export const TableGroupNode: FC<Props> = ({ data }) => {
  return (
    <div
      className={styles.wrapper}
      style={{
        borderColor: data.color,
        backgroundColor: `${data.color}12`,
      }}
    >
      <div className={styles.header}>
        <span className={styles.label} style={{ color: data.color }}>
          {data.label}
        </span>
        {data.description !== '' && (
          <span className={styles.description}>{data.description}</span>
        )}
      </div>
    </div>
  )
}
