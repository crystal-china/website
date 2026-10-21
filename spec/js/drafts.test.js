import { afterEach, beforeEach, expect, test } from "bun:test";
import setupDraft, { clearSavedDraft } from "../../src/js/drafts.js";

const originalWindow = globalThis.window;
let storage;

beforeEach(() => {
    storage = new Map();
    globalThis.window = {
        localStorage: {
            getItem: (key) => storage.get(key) ?? null,
            setItem: (key, value) => storage.set(key, value),
            removeItem: (key) => storage.delete(key),
        },
    };
});

afterEach(() => {
    globalThis.window = originalWindow;
});

function editor(key, values = { content: "" }) {
    const listeners = new Map();
    const fields = Object.entries(values).map(([name, value]) => ({ name, value }));
    const container = {
        dataset: { draftKey: key },
        querySelectorAll: () => fields,
        addEventListener(name, callback) {
            listeners.set(name, [...(listeners.get(name) ?? []), callback]);
        },
    };
    setupDraft(container);
    return {
        container,
        fields,
        input() { listeners.get("input").forEach((callback) => callback()); },
        change() { listeners.get("change").forEach((callback) => callback()); },
        listenerCount() { return listeners.get("input").length; },
    };
}

function response(container, { ok = true, saved = null } = {}) {
    return { detail: { ctx: {
        sourceElement: { closest: () => container },
        response: { raw: { ok, headers: { get: () => saved } } },
    } } };
}

test("restores title, node and content after repeated reloads without consuming the draft", () => {
    const first = editor("1:topic:new", { "topic:title": "", "topic:node_id": "", content: "" });
    expect(storage.size).toBe(0);
    first.fields[0].value = "测试草稿";
    first.fields[1].value = "3";
    first.fields[2].value = "长正文\n\n**Markdown** @xiaoming";
    first.input();

    for (let index = 0; index < 3; index++) {
        const restored = editor("1:topic:new", { "topic:title": "", "topic:node_id": "", content: "" });
        expect(restored.fields).toEqual(first.fields);
        expect(storage.size).toBe(1);
    }
});

test("isolates users, new topics, edits, top-level comments and different reply targets", () => {
    const keys = ["1:topic:new", "2:topic:new", "1:topic:5:edit", "1:thread:5", "1:reply:5", "1:reply:6", "1:comment:5:edit"];
    for (const key of keys) {
        const draft = editor(key);
        draft.fields[0].value = key;
        draft.input();
    }
    for (const key of keys) {
        expect(editor(key).fields[0].value).toBe(key);
    }
});

test("remembers deliberately emptied fields and select changes", () => {
    const draft = editor("1:topic:new", { "topic:node_id": "1", content: "old content" });
    draft.input();
    draft.fields[0].value = "2";
    draft.fields[1].value = "";
    draft.change();
    expect(editor("1:topic:new", { "topic:node_id": "1", content: "old content" }).fields).toEqual(draft.fields);
});

test("does not clear drafts for previews, validation failures, expired sessions or failed requests", () => {
    const draft = editor("1:thread:5");
    draft.fields[0].value = "Keep this";
    draft.input();
    for (const result of [{}, { ok: false }, { ok: false, saved: "true" }]) {
        clearSavedDraft(response(draft.container, result));
        expect(storage.size).toBe(1);
    }
    clearSavedDraft(response(null, { saved: "true" }));
    expect(storage.size).toBe(1);
});

test("clears only the submitted editor when the server confirms success", () => {
    const first = editor("1:reply:5");
    const second = editor("1:reply:6");
    first.input();
    second.input();
    clearSavedDraft(response(first.container, { saved: "true" }));
    expect(storage.has("draft:1:reply:5")).toBe(false);
    expect(storage.has("draft:1:reply:6")).toBe(true);
    expect(editor("1:reply:5").fields[0].value).toBe("");
});

test("initializes each element once but restores newly swapped editors", () => {
    const first = editor("1:reply:5");
    setupDraft(first.container);
    expect(first.listenerCount()).toBe(1);
    first.fields[0].value = "Reply";
    first.input();
    expect(editor("1:reply:5").fields[0].value).toBe("Reply");
});

test("ignores corrupt drafts and replaces them on the next input", () => {
    storage.set("draft:1:reply:5", "invalid JSON");
    const draft = editor("1:reply:5");
    draft.fields[0].value = "Recovered";
    draft.input();
    expect(editor("1:reply:5").fields[0].value).toBe("Recovered");
});

test("does not interrupt editing or successful submissions when storage is unavailable", () => {
    Object.defineProperty(window, "localStorage", { get() { throw new Error("Storage blocked"); } });
    const draft = editor("1:reply:5");
    expect(() => draft.input()).not.toThrow();
    expect(() => clearSavedDraft(response(draft.container, { saved: "true" }))).not.toThrow();
});
