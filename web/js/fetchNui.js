const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "ox_target";

export async function fetchNui(eventName, data) {
  try {
    const resp = await fetch(`https://${resource}/${eventName}`, {
      method: "post",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data),
    });
    return await resp.json();
  } catch {
    return null;
  }
}
