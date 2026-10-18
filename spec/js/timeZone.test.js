import { afterEach, beforeEach, expect, spyOn, test } from "bun:test";
import saveTimeZone from "../../src/js/timeZone.js";

const originalDocument = globalThis.document;
const originalLocation = globalThis.location;
let formatter;
let writes;
let cookies;

beforeEach(() => {
    writes = [];
    cookies = "other=1";
    globalThis.document = {
        get cookie() { return cookies; },
        set cookie(value) {
            writes.push(value);
            cookies = value.split(";", 1)[0];
        },
    };
    globalThis.location = { protocol: "https:" };
    formatter = spyOn(Intl, "DateTimeFormat").mockImplementation(() => ({
        resolvedOptions: () => ({ timeZone: "Asia/Shanghai" }),
    }));
});

afterEach(() => {
    formatter.mockRestore();
    globalThis.document = originalDocument;
    globalThis.location = originalLocation;
});

test("saves the browser time zone as a host-only cookie without reloading", () => {
    saveTimeZone();

    expect(writes).toEqual([
        "time_zone=Asia%2FShanghai; Path=/; Max-Age=31536000; SameSite=Lax; Secure",
    ]);
});

test("does not rewrite an unchanged time zone", () => {
    cookies = "other=1; time_zone=Asia%2FShanghai; another=2";
    saveTimeZone();
    expect(writes).toEqual([]);
});

test("updates a changed time zone and supports local HTTP development", () => {
    cookies = "time_zone=UTC";
    location.protocol = "http:";
    saveTimeZone();
    expect(writes).toEqual([
        "time_zone=Asia%2FShanghai; Path=/; Max-Age=31536000; SameSite=Lax",
    ]);
});

test("leaves the server fallback when the browser cannot supply a time zone", () => {
    formatter.mockImplementation(() => ({ resolvedOptions: () => ({}) }));
    saveTimeZone();
    expect(writes).toEqual([]);

    formatter.mockImplementation(() => { throw new Error("Intl unavailable"); });
    expect(() => saveTimeZone()).not.toThrow();
    expect(writes).toEqual([]);
});

test("does not interrupt the page when cookies are blocked", () => {
    globalThis.document = {
        get cookie() { return ""; },
        set cookie(value) { throw new Error("Cookies blocked"); },
    };
    expect(() => saveTimeZone()).not.toThrow();
});
