import htmx from 'htmx.org';
window.htmx = htmx;
import tabs from 'missing.css/www/missing-js/tabs.js';

function init () {
    htmx.logger = function (elt, event, data) {
        if (console) {
            console.log(event, elt, data);
        }
    };

    let tabs_div = document.querySelector("#tabs");
    if (tabs_div != null) {
        tabs(document.querySelector("#tabs"));
    }
}

htmx.onLoad(init);
