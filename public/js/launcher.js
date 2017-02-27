(function ( $ ) {
    /* global counter for constructing unique IDs */
    abaloneInstanceCount = 0;

    $.fn.AbaloneLauncher = function(options) {
      var settings = $.extend({
      location: 'ne',
         label: "Launch",
         title: "Abalone Web Shell",
        target: "popup",
        params: {},
        server: null,
        height: 480,
         width: 640,
      }, options );

      return this.each(function() {
        if (settings.server == null) {
          console.log("[FATAL] Abalone: server is a required parameter.")
          return;
        }

        abaloneInstanceCount++;
        var element   = $(this);
        var serverURL = settings.server + '?' + $.param(settings.params);

        if (element.css("display") == "block") {
          var launcher = $("<input>", {
                             "type": "button",
                            "class": "launcher",
                            "value": settings.label,
                          });

          launcher.addClass("control");

          if (-1 != $.inArray(settings.location, ["ne", "se", "sw", "nw"])) {
            launcher.addClass("location-" + settings.location);
          }

          /* we need this for the absolutely posititioned button */
          if (element.css("position") == "static" ) {
            element.css("position", "relative");
          }

          element.prepend(launcher);
        } else {
          if (settings.target == "inline") {
            console.log("[FATAL] Abalone: you cannot use the inline target without a container.")
            return;
          }
          var launcher = element;
        }
        launcher.addClass("abalone launcher instance-"+abaloneInstanceCount);
        launcher.click(function(e) {
          e.preventDefault();
          var button = $(this);
          switch(settings.target) {
            case "popup":
              var abalone = $("<iframe>", { "class": "abalone popup", "src": serverURL });
              abalone.dialog({
                height: settings.height,
                 width: settings.width,
                 title: settings.title,
                 close: function( event, ui ) {
                          button.prop('disabled', false);
                          abalone.remove();
                        }
              });
              button.prop('disabled', true);
              break;

            case "inline":
              var abalone = $("<iframe>", { "class": "abalone inline", "src": serverURL });
              element.append(abalone);
              break;

            case "tab":
              window.open(serverURL, 'abaloneTerminal');
              break

            /* Assume that the user has passed in a string as a selector target */
            default:
              var abalone = $("<iframe>", { "class": "abalone targeted", "src": serverURL });
              var target  = $(settings.target)
              target.append(abalone);
              break;
          }

          /* swap out for the close button, unless we're using a popup/tab */
          if (["popup", "tab"].indexOf(settings.target) == -1) {
            var close = $("<input>", {
               "type": "button",
              "class": "abalone inline control exit location-" + settings.location,
              "value": "Close",
            });
            close.on("click", function() {
              $(this).remove();
              abalone.remove();
              button.show();
            });

            element.prepend(close);
            button.hide();
          }

        });

        return this;
      });
    };

}(jQuery));
