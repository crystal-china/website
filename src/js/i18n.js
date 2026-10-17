let currentElement;
let messages = {};

export default function t(key, values = {}) {
    const element = document.getElementById("i18n-messages");

    // Cache per body, not per application load: hx-boost can change the locale.
    if (element !== currentElement) {
        currentElement = element;
        messages = JSON.parse(element?.textContent ?? "{}");
    }

    if (!Object.hasOwn(messages, key)) {
        throw new Error(`Missing frontend translation: ${key}`);
    }

    return messages[key].replace(/%\{(\w+)\}/g, (_, name) => {
        if (!Object.hasOwn(values, name)) {
            throw new Error(`Missing translation argument: ${name}`);
        }

        return String(values[name]);
    });
}
