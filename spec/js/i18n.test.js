import { afterEach, describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import t from "../../src/js/i18n.js";

const originalDocument = globalThis.document;

afterEach(() => {
    globalThis.document = originalDocument;
});

describe("frontend translations", () => {
    test("caches one body and reloads messages after an HTMX body replacement", () => {
        let reads = 0;
        let element = {
            get textContent() {
                reads++;
                return JSON.stringify({ copied: "已复制" });
            },
        };
        globalThis.document = { getElementById: () => element };

        expect(t("copied")).toBe("已复制");
        expect(t("copied")).toBe("已复制");
        expect(reads).toBe(1);

        element = { textContent: JSON.stringify({ copied: "Copied" }) };
        expect(t("copied")).toBe("Copied");
    });

    test("interpolates values literally, including replacement metacharacters", () => {
        globalThis.document = {
            getElementById: () => ({ textContent: JSON.stringify({ message: "Upload failed: %{reason}" }) }),
        };

        expect(t("message", { reason: "$& <script>" })).toBe("Upload failed: $& <script>");
        expect(() => t("message")).toThrow("Missing translation argument: reason");
        expect(() => t("missing")).toThrow("Missing frontend translation: missing");
    });

    test("exports every key used by the frontend from compile-checked Rosetta lookups", () => {
        const backend = readFileSync("src/components/shared/translations.cr", "utf8");
        const keys = new Set([...backend.matchAll(/"([a-z_]+)"\s*=>\s*r\("javascript\./g)].map((match) => match[1]));

        for (const file of ["app", "htmxErrorAlert", "pasteImage", "mentions", "copyCodeButton"]) {
            const source = readFileSync(`src/js/${file}.js`, "utf8");

            for (const match of source.matchAll(/\bt\("([a-z_]+)"/g)) {
                expect(keys.has(match[1])).toBe(true);
            }
        }

        expect(keys.size).toBe(17);
    });
});
