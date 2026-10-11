import { createOptions } from "./createOptions.js";

const optionsWrapper = document.getElementById("options-wrapper");
const eye = document.getElementById("eye");

function clear() {
  optionsWrapper.replaceChildren();
  eye.classList.remove("eye-hover");
}

window.addEventListener("message", ({ data }) => {
  switch (data.event) {
    case "visible":
      clear();
      document.body.classList.toggle("hidden", !data.state);
      return;

    case "leftTarget":
      return clear();

    case "setTarget": {
      clear();
      eye.classList.add("eye-hover");

      if (data.options) {
        for (const type in data.options) {
          const list = data.options[type];
          if (Array.isArray(list)) list.forEach((option, id) => createOptions(type, option, id + 1));
        }
      }

      if (Array.isArray(data.zones)) {
        data.zones.forEach((zone, i) => zone.forEach((option, id) => createOptions("zones", option, id + 1, i + 1)));
      }
    }
  }
});
