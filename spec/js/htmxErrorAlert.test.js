import { expect, test } from "bun:test";
import setupHtmxErrorAlert from "../../src/js/htmxErrorAlert.js";

test("allows successful head merges but keeps error responses from changing the current page head", () => {
    const originalDocument = globalThis.document;

    try {
        globalThis.document = new EventTarget();
        setupHtmxErrorAlert({});

        for (const status of [200, 404, 500]) {
            const event = new CustomEvent("htmx:head:before:merge", {
                cancelable: true,
                detail: { ctx: { response: { status } } },
            });

            document.dispatchEvent(event);
            expect(event.defaultPrevented).toBe(status >= 400);
        }
    } finally {
        globalThis.document = originalDocument;
    }
});
