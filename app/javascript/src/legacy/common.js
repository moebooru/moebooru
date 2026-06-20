/* globals $, Element */
Object.extend(Element.Methods, {
  showBase: Element.show,
  show (element, visible) {
    if (visible || visible == null) {
      $(element).showBase();
    } else {
      $(element).hide();
    }
  }
});
Element.addMethods();
