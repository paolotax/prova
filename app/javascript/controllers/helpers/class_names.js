export function classNames(options) {
  return Object.keys(options).filter(key => options[key]).join(" ");
}
