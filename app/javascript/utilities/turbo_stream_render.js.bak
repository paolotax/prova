document.addEventListener("turbo:before-stream-render", (event) => {
  const { target } = event;

  if (!(target.firstElementChild instanceof HTMLTemplateElement)) return

  const { dataset, templateElement } = target;
  const { transitionEnter, transitionLeave } = dataset;

  if (transitionEnter !== undefined) {
    handleTransitionEnter(event, templateElement, dataset);
  }

  if (transitionLeave !== undefined) {
    handleTransitionLeave(event, target, dataset);
  }
})

const handleTransitionEnter = (event, templateElement, dataset) => {
  event.preventDefault();

  const firstChild = templateElement.content.firstElementChild;

  Object.assign(firstChild.dataset, dataset);

  firstChild.setAttribute("hidden", "");
  firstChild.setAttribute("data-controller", "appear");

  event.target.performAction();
}

const handleTransitionLeave = (event, target, dataset) => {
  const leaveElement = document.getElementById(target.target);
  if (!leaveElement) return

  event.preventDefault();

  Object.assign(leaveElement.dataset, dataset);

  leaveElement.setAttribute("data-controller", "disappear");
}
