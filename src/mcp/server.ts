#!/usr/bin/env node
import { config } from "dotenv";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { env } from "../config.js";
import { formatEarningsDashboard, getEarningsSummary, getReceipt } from "../receipts.js";

config();

const server = new Server(
  { name: "pharos-x402-paywall", version: "1.1.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "facilitator_health",
      description: "Check x402 facilitator /supported endpoint",
      inputSchema: { type: "object", properties: {}, additionalProperties: false },
    },
    {
      name: "paywall_probe",
      description: "Send unpaid request to paywall URL and return status + headers",
      inputSchema: {
        type: "object",
        properties: {
          url: { type: "string", description: "Paywall resource URL (default /insight)" },
        },
        additionalProperties: false,
      },
    },
    {
      name: "get_earnings",
      description: "Read getEarningsSummary dashboard for a payee",
      inputSchema: {
        type: "object",
        properties: {
          payee: { type: "string", description: "Payee address (defaults to PAYEE_ADDRESS)" },
        },
        additionalProperties: false,
      },
    },
    {
      name: "get_receipt",
      description: "Read on-chain receipt by id",
      inputSchema: {
        type: "object",
        properties: { id: { type: "number", description: "Receipt id" } },
        required: ["id"],
        additionalProperties: false,
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    if (name === "facilitator_health") {
      const res = await fetch(`${env.facilitatorUrl}/supported`);
      const body = await res.text();
      return {
        content: [{ type: "text", text: `status=${res.status}\n${body}` }],
      };
    }

    if (name === "paywall_probe") {
      const url = (args?.url as string) || `http://localhost:${env.port}/insight`;
      const res = await fetch(url);
      const headers = Object.fromEntries(res.headers.entries());
      const body = await res.text();
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              { status: res.status, headers, body: body.slice(0, 500) },
              null,
              2
            ),
          },
        ],
      };
    }

    if (name === "get_earnings") {
      const payee = (args?.payee as `0x${string}`) || env.payeeAddress;
      if (!payee) throw new Error("payee required (arg or PAYEE_ADDRESS)");
      const summary = await getEarningsSummary(payee, env.usdcAddress);
      return {
        content: [
          {
            type: "text",
            text: `Earnings dashboard for ${payee}\n${formatEarningsDashboard(summary)}`,
          },
        ],
      };
    }

    if (name === "get_receipt") {
      const id = BigInt(args?.id as number);
      const receipt = await getReceipt(id);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(receipt, (_, v) => (typeof v === "bigint" ? v.toString() : v), 2),
          },
        ],
      };
    }

    throw new Error(`Unknown tool: ${name}`);
  } catch (err) {
    return {
      content: [{ type: "text", text: `Error: ${(err as Error).message}` }],
      isError: true,
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
