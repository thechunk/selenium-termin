feather = require('feather-icons');
window.htmx = require('htmx.org');

window.configure = function(f) {
  return function() {
    f.replace({
      width: 18,
      height: 18,
      'stroke-width': 1
    });
  };
}(feather);
window.configure();
