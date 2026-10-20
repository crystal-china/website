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
            createElement: element,
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

    function element() {
        const classes = new Set();
        return {
            hidden: true,
            children: [],
            listeners: {},
            classList: {
                toggle(name, enabled) { enabled ? classes.add(name) : classes.delete(name); },
                contains(name) { return classes.has(name); },
            },
            replaceChildren(...children) { this.children = children; },
            addEventListener(name, handler) { this.listeners[name] = handler; },
        };
    }

    async function type(content, caret = content.length) {
        closeEditor?.();

        const listeners = new Map();
        const list = element();
        const textarea = {
            value: content,
            selectionStart: caret,
            selectionEnd: caret,
            isConnected: true,
            dataset: { usersAutocompleteUrl: "/htmx/users/autocomplete" },
            parentElement: { querySelector: () => list },
            setRangeText(text, start, end) {
                this.value = this.value.slice(0, start) + text + this.value.slice(end);
                this.selectionStart = this.selectionEnd = start + text.length;
            },
            dispatchEvent(event) { listeners.get(event.type)?.(event); },
            addEventListener: (event, listener) => listeners.set(event, listener),
        };

        document.activeElement = textarea;
        setupMentions(textarea);
        closeEditor = listeners.get("blur");
        listeners.get("input")({ isComposing: false });

        await new Promise((resolve) => setTimeout(resolve, 300));

        return { textarea, list, listeners };
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

    test("switches candidates with arrow keys and confirms only the mention with Tab or Enter", async () => {
        globalThis.fetch = async (url) => {
            requests.push(url.searchParams.get("q"));
            return { ok: true, json: async () => [
                { login_name: "zw963", nickname: "Billy" },
                { login_name: "zw964", nickname: "Other" },
            ] };
        };
        const content = "你好 @zw，后面还有正文";
        for (const confirmKey of ["Tab", "Enter"]) {
            const { textarea, list, listeners } = await type(content, content.indexOf("，"));
            const press = (key) => {
                const event = { key, prevented: false, preventDefault() { this.prevented = true; }, stopPropagation() {} };
                listeners.get("keydown")(event);
                return event;
            };

            expect(list.hidden).toBe(false);
            expect(list.children[0].classList.contains("bg-sky-50")).toBe(true);
            expect(press("ArrowDown").prevented).toBe(true);
            expect(list.children[1].classList.contains("bg-sky-50")).toBe(true);
            press("ArrowUp");
            expect(list.children[0].classList.contains("bg-sky-50")).toBe(true);
            expect(textarea.value).toBe(content);
            expect(press(confirmKey).prevented).toBe(true);
            expect(textarea.value).toBe("你好 @zw963 ，后面还有正文");
            expect(textarea.selectionStart).toBe("你好 @zw963 ".length);
            expect(list.hidden).toBe(true);
            await Bun.sleep(300);
        }
        expect(requests).toEqual(["zw", "zw"]);
    });

    test("ignores a response when the caret has moved to another identical mention", async () => {
        let resolve;
        globalThis.fetch = () => new Promise((callback) => { resolve = callback; });
        const { textarea, list } = await type("@zw 和 @zw", 3);
        textarea.selectionStart = textarea.selectionEnd = textarea.value.length;
        resolve({ ok: true, json: async () => [{ login_name: "zw963", nickname: "Billy" }] });
        await Bun.sleep(0);
        expect(list.hidden).toBe(true);
        expect(list.children).toHaveLength(0);
    });

    test("does not replace text when the caret moves after candidates have loaded", async () => {
        globalThis.fetch = async () => ({ ok: true, json: async () => [{ login_name: "zw963", nickname: "Billy" }] });
        const { textarea, list, listeners } = await type("@zw 和 @zw", 3);
        textarea.selectionStart = textarea.selectionEnd = textarea.value.length;
        listeners.get("keydown")({ key: "Enter", preventDefault() {}, stopPropagation() {} });
        expect(textarea.value).toBe("@zw 和 @zw");
        expect(list.hidden).toBe(true);
    });
});
