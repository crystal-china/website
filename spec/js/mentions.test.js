import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import setupMentions from "../../src/js/mentions.js";

describe("mention autocomplete boundaries", () => {
    let originalGlobals;
    let requests;
    let closeEditor;

    beforeEach(() => {
        originalGlobals = { document: globalThis.document, location: globalThis.location, fetch: globalThis.fetch };
        requests = [];
        globalThis.document = {
            activeElement: null,
            createElement: () => ({ setAttribute() {}, replaceChildren() {} }),
        };
        globalThis.location = { origin: "http://example.test" };
        globalThis.fetch = async (url) => {
            requests.push(url.searchParams.get("q"));
            return { ok: true, json: async () => [] };
        };
    });

    afterEach(() => {
        closeEditor?.();
        Object.assign(globalThis, originalGlobals);
    });

    async function type(content) {
        closeEditor?.();

        const listeners = new Map();
        const textarea = {
            value: content,
            selectionStart: content.length,
            selectionEnd: content.length,
            isConnected: true,
            dataset: { mentionsUrl: "/htmx/mentions" },
            parentElement: { classList: { add() {} } },
            after() {},
            setAttribute() {},
            removeAttribute() {},
            addEventListener: (event, listener) => listeners.set(event, listener),
        };

        document.activeElement = textarea;
        setupMentions(textarea);
        closeEditor = listeners.get("blur");
        listeners.get("input")({ isComposing: false });

        await new Promise((resolve) => setTimeout(resolve, 300));
    }

    test("accepts the same preceding characters as the server", async () => {
        for (const content of ["@zw963", "hello_@zw963", "_@zw963", "请@zw963", "(@zw963"]) {
            await type(content);
        }

        expect(requests).toEqual(Array(5).fill("zw963"));
    });

    test("rejects letters, digits, another at sign, and short prefixes", async () => {
        for (const content of ["email@zw963", "1@zw963", "@@zw963", "@z"]) {
            await type(content);
        }

        expect(requests).toEqual([]);
    });

    test("only completes mentions after an even number of backslashes", async () => {
        for (let count = 0; count <= 5; count++) {
            await type(`谢谢 ${"\\".repeat(count)}@zw963`);

            expect(requests.length).toBe(Math.floor(count / 2) + 1);
        }
    });
});
