function findElements(root, selector) {
    const elements = [...root.querySelectorAll(selector)];

    if (root.matches(selector)) {
        elements.unshift(root);
    }

    return elements;
}

export default findElements;
