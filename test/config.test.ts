import { describe, expect, it } from "vitest";
import { resourceIdForRoute } from "../src/config.js";

describe("resourceIdForRoute", () => {
  it("hashes method and path consistently", () => {
    const a = resourceIdForRoute("GET", "/insight");
    const b = resourceIdForRoute("GET", "/insight");
    expect(a).toBe(b);
    expect(a).toMatch(/^0x[0-9a-f]{64}$/);
  });

  it("differs for different routes", () => {
    expect(resourceIdForRoute("GET", "/insight")).not.toBe(resourceIdForRoute("GET", "/api/info"));
  });
});
