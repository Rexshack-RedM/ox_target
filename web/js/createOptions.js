import { fetchNui } from "./fetchNui.js";

const optionsWrapper = document.getElementById("options-wrapper");

function onClick() {
  // when NUI focus drops after a click the hover state never releases, so block repeat clicks briefly
  if (this.dataset.busy) return;
  this.dataset.busy = "1";
  fetchNui("select", [this.targetType, this.targetId, this.zoneId]);
  setTimeout(() => delete this.dataset.busy, 150);
}

export function createOptions(type, data, id, zoneId) {
  if (data.hide) return;

  const option = document.createElement("div");
  option.className = "option-container";

  const badge = document.createElement("span");
  badge.className = "option-badge";
  const icon = document.createElement("i");
  icon.className = `fa-fw ${data.icon || "fa-solid fa-circle"}`;
  if (data.iconColor) icon.style.color = data.iconColor;
  badge.appendChild(icon);

  const label = document.createElement("p");
  label.className = "option-label";
  label.textContent = data.label ?? ""; // textContent: never render option labels as HTML

  option.append(badge, label);
  option.targetType = type;
  option.targetId = id;
  option.zoneId = zoneId;
  option.addEventListener("click", onClick);
  optionsWrapper.appendChild(option);
}
