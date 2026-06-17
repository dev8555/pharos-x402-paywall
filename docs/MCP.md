# MCP Server

Expose pharos-x402-paywall operations as MCP tools for Cursor and other MCP clients.

## Start

```bash
npm run mcp
```

Uses stdio transport (`@modelcontextprotocol/sdk`).

## Tools

| Tool | Description |
|------|-------------|
| `facilitator_health` | GET `{FACILITATOR_URL}/supported` |
| `paywall_probe` | Unpaid request to paywall URL (expect 402) |
| `get_earnings` | `getEarningsSummary` dashboard for payee |
| `get_receipt` | Read on-chain receipt by id |

## Cursor configuration

Add to MCP settings (adjust `cwd`):

```json
{
  "mcpServers": {
    "pharos-x402": {
      "command": "npm",
      "args": ["run", "mcp"],
      "cwd": "D:/pharos-x402-paywall"
    }
  }
}
```

Requires `.env` with `RECEIPTS_ADDRESS`, `EVM_PRIVATE_KEY` (for read/write tools), and running facilitator/server for probes.

## Agent CLI fallback

Without MCP:

```bash
npm run agent -- health
npm run agent -- probe http://localhost:4021/insight
npm run agent -- earnings
npm run agent -- receipt 0
```

See [SKILL.md](../SKILL.md) for the full agent skill entry point.
