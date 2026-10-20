import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import setupUserAutocomplete from "../../src/js/userAutocomplete.js";

describe("user autocomplete", () => {
    let originalGlobals;
    let input;
    let list;
    let listeners;
    let requests;
    let registrations;

    beforeEach(() => {
        originalGlobals = { document: globalThis.document, location: globalThis.location, fetch: globalThis.fetch };
        listeners = new Map();
        requests = [];
        registrations = 0;
        list = element();
        list.hidden = true;
        input = {
            ...element(),
            value: "",
            isConnected: true,
            dataset: { usersAutocompleteUrl: "/htmx/users/autocomplete" },
            parentElement: { querySelector: () => list },
            dispatchEvent(event) { listeners.get(event.type)?.(event); },
            addEventListener(event, listener) {
                registrations++;
                listeners.set(event, listener);
            },
        };
        globalThis.document = {
            activeElement: input,
            createElement: element,
        };
        globalThis.location = { origin: "http://example.test" };
        globalThis.fetch = async (url, options) => {
            requests.push({ url, options });
            return { ok: true, json: async () => [{ login_name: "zw963", nickname: "Billy Zheng" }] };
        };
        setupUserAutocomplete(input);
    });

    afterEach(() => {
        type("");
        Object.assign(globalThis, originalGlobals);
    });

    function type(value, isComposing = false) {
        input.value = value;
        listeners.get("input")({ isComposing });
    }

    function element() {
        const classes = new Set();
        return {
            children: [],
            listeners: {},
            classList: {
                toggle(name, enabled) { enabled ? classes.add(name) : classes.delete(name); },
                contains(name) { return classes.has(name); },
            },
            replaceChildren(...children) { this.children = children; },
            addEventListener(name, handler) { this.listeners[name] = handler; },
            scrollIntoView() {},
        };
    }

    function key(value, isComposing = false, shiftKey = false) {
        const event = { key: value, isComposing, shiftKey, prevented: false, preventDefault() { this.prevented = true; }, stopPropagation() {} };
        listeners.get("keydown")(event);
        return event;
    }

    test("waits for two characters and debounces input before showing clickable candidates", async () => {
        type("z");
        await Bun.sleep(300);
        type("zw", true);
        await Bun.sleep(300);
        expect(requests).toHaveLength(0);

        type("zw");
        type("zw9");
        await Bun.sleep(300);

        expect(requests).toHaveLength(1);
        expect(requests[0].url.pathname).toBe("/htmx/users/autocomplete");
        expect(requests[0].url.searchParams.get("q")).toBe("zw9");
        expect(requests[0].options.headers["HX-Request-Type"]).toBe("partial");
        expect(list.hidden).toBe(false);
        expect(list.children[0].textContent).toBe("Billy Zheng @zw963");
        expect(list.children[0].type).toBe("button");
        const pointer = { prevented: false, preventDefault() { this.prevented = true; } };
        list.children[0].listeners.pointerdown(pointer);
        expect(pointer.prevented).toBe(true);
        list.children[0].listeners.click();
        expect(input.value).toBe("zw963");
        expect(list.hidden).toBe(true);
        await Bun.sleep(300);
        expect(requests).toHaveLength(1);
        type("z");
        expect(list.children).toEqual([]);
        expect(requests[0].options.signal.aborted).toBe(true);
    });

    test("aborts old requests and ignores their responses even if transport cancellation is delayed", async () => {
        const pending = [];
        globalThis.fetch = (url, options) => new Promise((resolve) => pending.push({ url, options, resolve }));
        type("zw");
        await Bun.sleep(300);
        type("ab");
        await Bun.sleep(300);

        expect(pending[0].options.signal.aborted).toBe(true);
        pending[0].resolve({ ok: true, json: async () => [{ login_name: "zw963", nickname: "Old" }] });
        await Bun.sleep(0);
        expect(list.children).toEqual([]);

        pending[1].resolve({ ok: true, json: async () => [{ login_name: "abc", nickname: "New" }] });
        await Bun.sleep(0);
        expect(list.children[0].textContent).toBe("New @abc");
    });

    test("does not attach duplicate listeners or request candidates for a removed input", async () => {
        setupUserAutocomplete(input);
        expect(registrations).toBe(4);
        type("zw");
        input.isConnected = false;
        await Bun.sleep(300);
        expect(requests).toHaveLength(0);
    });

    test("finds the named list even when another element follows the input", async () => {
        const inserted = element();
        input = { ...input, nextElementSibling: inserted };
        document.activeElement = input;
        setupUserAutocomplete(input);
        type("zw");
        await Bun.sleep(300);

        expect(list.hidden).toBe(false);
        expect(list.children[0].textContent).toBe("Billy Zheng @zw963");
        expect(inserted.children).toHaveLength(0);
    });

    test("leaves manual input usable when the server rejects the request or the network fails", async () => {
        globalThis.fetch = async () => ({ ok: false });
        type("zw");
        await Bun.sleep(300);
        expect(input.value).toBe("zw");
        expect(list.children).toEqual([]);

        globalThis.fetch = async () => { throw new Error("offline"); };
        type("abc");
        await Bun.sleep(300);
        expect(input.value).toBe("abc");
        expect(list.children).toEqual([]);
    });

    test("supports arrow keys and Enter without submitting the form while choosing", async () => {
        globalThis.fetch = async () => ({ ok: true, json: async () => [
            { login_name: "zw963", nickname: "Billy" },
            { login_name: "zw964", nickname: "Other" },
        ] });
        type("zw");
        await Bun.sleep(300);
        key("ArrowDown", true);
        expect(list.children[0].classList.contains("bg-sky-50")).toBe(false);
        expect(key("ArrowDown").prevented).toBe(true);
        expect(list.children[0].classList.contains("bg-sky-50")).toBe(true);
        key("ArrowUp");
        expect(list.children[0].classList.contains("bg-sky-50")).toBe(false);
        expect(list.children[1].classList.contains("bg-sky-50")).toBe(true);
        expect(key("Enter").prevented).toBe(true);
        expect(input.value).toBe("zw964");
        expect(list.hidden).toBe(true);
        expect(key("Enter").prevented).toBe(false);
    });

    test("leaves account Tab keys untouched and closes the list only after blur", async () => {
        expect(key("Tab").prevented).toBe(false);
        globalThis.fetch = async () => ({ ok: true, json: async () => [
            { login_name: "zw963", nickname: "Billy" },
            { login_name: "zw964", nickname: "Other" },
        ] });
        type("zw");
        await Bun.sleep(300);
        expect(key("Tab").prevented).toBe(false);
        expect(input.value).toBe("zw");
        expect(list.hidden).toBe(false);
        listeners.get("blur")();
        expect(list.hidden).toBe(true);

        type("zw");
        await Bun.sleep(300);
        key("ArrowUp");
        expect(key("Tab").prevented).toBe(false);
        expect(input.value).toBe("zw");
        expect(list.hidden).toBe(false);
        listeners.get("blur")();
        expect(list.hidden).toBe(true);

        type("zw");
        await Bun.sleep(300);
        key("ArrowDown");
        expect(key("Tab", false, true).prevented).toBe(false);
        expect(input.value).toBe("zw");
        expect(list.hidden).toBe(false);
        listeners.get("blur")();
        expect(list.hidden).toBe(true);
    });

    test("closes on Escape, click or blur and ignores responses arriving after blur", async () => {
        type("zw");
        await Bun.sleep(300);
        key("Escape");
        expect(list.hidden).toBe(true);
        expect(input.value).toBe("zw");
        type("zw");
        await Bun.sleep(300);
        listeners.get("click")();
        expect(list.hidden).toBe(true);
        let resolve;
        globalThis.fetch = () => new Promise((callback) => { resolve = callback; });
        type("zw");
        await Bun.sleep(300);
        listeners.get("blur")();
        resolve({ ok: true, json: async () => [{ login_name: "zw963", nickname: "Billy" }] });
        await Bun.sleep(0);
        expect(list.hidden).toBe(true);
        expect(list.children).toHaveLength(0);
    });

    test("does not display an empty list", async () => {
        globalThis.fetch = async () => ({ ok: true, json: async () => [] });
        type("zz");
        await Bun.sleep(300);
        expect(list.hidden).toBe(true);
    });
});
