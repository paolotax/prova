export function verticalNavigation(target, selectorTag = ["a"], scrollIntoViewEnabled = false) {
  let allItems = [];

  selectorTag.forEach(tag => {
    allItems = allItems.concat(Array.from(target.querySelectorAll(tag)));
  });

  const items = allItems.filter(item => !item.closest("li").hasAttribute("hidden"));
  const currentIndex = Array.from(items).indexOf(document.activeElement);

  if (items.length === 0) { return; }

  switch(event.key) {
  case "ArrowDown": {

    event.preventDefault();

    const nextIndex = (currentIndex + 1) % items.length;

    items[nextIndex].focus();

    if(scrollIntoViewEnabled) { scrollIntoView(items[nextIndex]); }

    break;
  }
  case "ArrowUp": {
    event.preventDefault();

    const previousIndex = (currentIndex - 1 + items.length) % items.length;

    items[previousIndex].focus();

    if(scrollIntoViewEnabled) { scrollIntoView(items[previousIndex]); }

    break;
  }
  }
}

export function horizontalNavigation(target, selectorTag = ["a"], scrollIntoViewEnabled = false) {
  let allItems = [];

  selectorTag.forEach(tag => {
    allItems = allItems.concat(Array.from(target.querySelectorAll(tag)));
  });

  const items = allItems.filter(item => !item.closest("li").hasAttribute("hidden"));
  const currentIndex = Array.from(items).indexOf(document.activeElement);

  if (items.length === 0) { return; }

  switch(event.key) {
  case "ArrowRight": {
    event.preventDefault();

    const nextIndex = (currentIndex + 1) % items.length;

    items[nextIndex].focus();

    if(scrollIntoViewEnabled) { scrollIntoView(items[nextIndex]); }

    break;
  }
  case "ArrowLeft": {
    event.preventDefault();

    const previousIndex = (currentIndex - 1 + items.length) % items.length;

    items[previousIndex].focus();

    if(scrollIntoViewEnabled) { scrollIntoView(items[previousIndex]); }

    break;
  }
  }
}

function scrollIntoView(element) {
  var scrollContainer = element.parentNode;

  var elementTop = element.offsetTop;
  var elementBottom = elementTop + element.clientHeight;
  var containerTop = scrollContainer.scrollTop;
  var containerBottom = containerTop + scrollContainer.clientHeight;

  if (elementTop < containerTop) {
    element.scrollIntoView(true);
  } else if (elementBottom > containerBottom) {
    element.scrollIntoView(false);
  }
}
