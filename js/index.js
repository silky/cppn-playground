var storedState   = localStorage.getItem('cppn-playground');
var startingState = storedState ? JSON.parse(storedState) : null;

var node = document.getElementById("app");
var app  = Elm.Main.init({ flags: startingState, node: node });
var cppn   = new CppnNetwork();
var latent = new LatentCanvas();


app.ports.setStorage.subscribe(function(state) {
  localStorage.setItem('cppn-playground', JSON.stringify(state));
});

app.ports.startTraining.subscribe(function ()   { cppn.startTraining();   });
app.ports.stopTraining.subscribe(function ()    { cppn.stopTraining();    });
app.ports.startRandomWalk.subscribe(function () { cppn.startRandomWalk(); });
app.ports.stopRandomWalk.subscribe(function()   { cppn.stopRandomWalk(); });

app.ports.rerender.subscribe(function(newModelSpec) {
  cppn.modelSpec = newModelSpec;
  cppn.forward(true);
});

app.ports.resetModel.subscribe(function(newModelSpec) {
  // HACK: https://discourse.elm-lang.org/t/when-is-cmd-actually-processed/1008
  requestAnimationFrame( function () {
    cppn.resetModel(newModelSpec);
  });
});

app.ports.downloadBig.subscribe(function () { cppn.downloadBig(); });

app.ports.clearImage.subscribe(function () { 
  document.getElementById("paste").style.display       = "flex";
  document.getElementById("input-image").style.display = "none";
});

const elt = document.getElementById("uploaded-image");

function setupClipboardListener (cropper, options) {
  elt.onload = function () {
    document.getElementById("paste").style.display       = "none";
    document.getElementById("input-image").style.display = "flex";
    cropper.destroy();
    cropper = new Cropper(elt, options);
    app.ports.setCanTrain.send(true);
  }

  // https://stackoverflow.com/a/15369753
  document.onpaste = function (event) {
    // use event.originalEvent.clipboard for newer chrome versions
    var items = (event.clipboardData  || event.originalEvent.clipboardData).items;
    // find pasted image among pasted items
    var blob = null;
    for (var i = 0; i < items.length; i++) {
      if (items[i].type.indexOf("image") === 0) {
        blob = items[i].getAsFile();
      }
    }
    // load image if there is a pasted image
    if (blob !== null) {
      var reader = new FileReader();
      reader.onload = function(event) {
        elt.src = event.target.result;

      };
      reader.readAsDataURL(blob);
    }
  }
}


const options = {
  viewMode: 2,
  guides: false,
  aspectRatio: 1,
  autoCropArea: 1,
  cropBoxResizable: false,
  crop: function (event) {
    var data      = event.detail;
    var cropper   = this.cropper;
    var imageData = cropper.getImageData();
    var elt       = document.getElementById("actual-image-container");
    var canvas    = cropper.getCroppedCanvas({ "width": 100, "height": 100 })

    canvas.setAttribute("id", "image-to-match");
    elt.innerHTML = '';
    elt.appendChild(canvas);
  }
};


requestAnimationFrame( function() {
  const image   = document.getElementById('uploaded-image');
  const cropper = new Cropper(image, options);
  setupClipboardListener(cropper, options);


  const dropZone      = document.getElementById("paste");
  dropZone.ondrop     = dropHandler;
  dropZone.ondragover = dragOverHandler;
});


function dropHandler(ev) {
  ev.preventDefault();
  if (ev.dataTransfer.items) {
    for (var i = 0; i < ev.dataTransfer.items.length; i++) {
      if (ev.dataTransfer.items[i].kind === 'file') {
        var blob = ev.dataTransfer.items[i].getAsFile();
        if (blob !== null) {
          var reader = new FileReader();
          reader.onload = function(event) {
            elt.src = event.target.result;

          };
          reader.readAsDataURL(blob);
        }
        return;
      }
    }
  }
}

function dragOverHandler (ev) {
  ev.preventDefault();
}

