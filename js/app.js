class CppnNetwork {

  constructor () {
    this.net      = null;
    this.training = false;
    this.walking  = false;

    // this.red   = null;
    // this.green = null;
    // this.blue  = null;
  }


  /** */
  stopTraining () {
    this.training = false;
  }


  /** */
  forward (withIntermediate) {
    tf.tidy( () => {
      // Build input
      var data = this.buildInput(this.modelSpec.outputWidth, this.modelSpec.outputHeight, this.modelSpec.latentVector);

      // Push it through the network
      if ( withIntermediate === true ) {
        // Render ALL intermediate neurons
        var outputNames = []

        for (var i = 0; i <= this.modelSpec.network.layers.length; i++) {
          var name = this.net.getLayer( undefined, i ).output.name;
          outputNames.push( name );
        }
      } else {
        outputNames = [ this.net.getLayer( undefined, this.modelSpec.network.layers.length ).output.name ];
      }

      const outputs = this.net.execute(data, outputNames);
      this.renderEverything(outputs);
    } );
  }


  /** */
  buildInput (w, h, z) {
    return tf.tidy(() => {
      const x = tf.linspace(-1, 1, w);
      const y = tf.linspace(-1, 1, h);

      const xx = tf.matMul( tf.ones  ([h, 1]), x.reshape([1, w]) )
      const yy = tf.matMul( y.reshape([h, 1]), tf.ones  ([1, w]) );

      var data   = tf.stack( [xx, yy], -1 );

      // Add in the "z" stuff.
      const zvec = tf.tensor1d(z);
      const ones = tf.ones( [ w, h, 1] );
      data       = tf.concat( [data, tf.mul(ones, zvec)], 2 );

      // Add in batch dimension. Note, for some 
      // reason, the batch dimension is at the front.
      data = data.reshape( [1].concat( data.shape ) );
      return data;
    });
  }


  /** */
  renderEverything (outputs) {
    const smallSize = 20;
    var result = outputs[outputs.length - 1];

    // Render all the intermediate neurons
    if (outputs.length > 1 ){
      var l = 0;
      outputs.slice(0, outputs.length - 1).forEach( output => {
        var lastShape = output.shape[3];

        for (var i = 0; i < lastShape; i++) {
          var newShape = [output.shape[0], output.shape[1], output.shape[2], i + 1];
          var chunk    = output.stridedSlice( [0, 0, 0, i], newShape, [1, 1, 1, 1]);

          var nodeId = l + "-" + (i+1);

          chunk = tf.image.resizeBilinear(chunk, [smallSize, smallSize]);
          chunk = tf.sigmoid(chunk).dataSync();

          var node   = document.getElementById(nodeId);

          // Note: `toPixels` returns a promise; so it can't be used in a
          // "tidy", so it means things are annoying.
          // tf.browser.toPixels(chunk, node);
          this.drawPicture(node, chunk, smallSize, smallSize, 0, 0, true);
        }

        l += 1;
      });
    }

    // Render it in the final neuron
    const node = document.getElementById("final-neuron");
    this.drawPicture(node, result.dataSync(), this.modelSpec.outputWidth, this.modelSpec.outputHeight, 0, 0);
  }


  /** */
  drawPicture (node, data, w, h, i, j, blackAndWhite) {
    const ctx = node.getContext("2d");
    const img = new ImageData(w, h);

    for (let x = 0; x < w; x++) {
      for (let y = 0; y < h; y++) {
        const ix = (y*w + x) * 4;


        if ( blackAndWhite ) {
          const iv = (y*w + x);
          img.data[ix + 0] = Math.floor(255 * data[iv]);
          img.data[ix + 1] = Math.floor(255 * data[iv]);
          img.data[ix + 2] = Math.floor(255 * data[iv]);
        } else {
          const iv = (y*w + x) * 3;
          img.data[ix + 0] = Math.floor(255 * data[iv + 0]);
          img.data[ix + 1] = Math.floor(255 * data[iv + 1]);
          img.data[ix + 2] = Math.floor(255 * data[iv + 2]);
        }

        img.data[ix + 3] = 255;
      }
    }

    ctx.putImageData(img, i*w, j*w);
  }


  /** */
  resetModel (newModelSpec) {
    if ( this.net ) {
      tf.dispose(this.net);
    }

    tf.disposeVariables();

    this.modelSpec = newModelSpec;
    this.net       = this.buildNetwork();

    this.forward(true);
    latent.initialiseLatentVector();
  }


  /** */
  buildNetwork () {
    var first      = true;
    var index      = 0;
    var h          = this.modelSpec.outputHeight;
    var w          = this.modelSpec.outputWidth;
    var zdim       = this.modelSpec.latentDimensions;
    var inputShape = undefined;

    return tf.tidy( () => {
      const net = tf.sequential();

      this.modelSpec.network.layers.forEach( l => {
        var init = tf.initializers.randomNormal({ mean: 0, stddev: 1, seed: l.seed });
        index += 1;

        if (first) {
          first = false;
          inputShape = [h, w, 2 + zdim];
        } else {
          inputShape = undefined;
        }

        const spec = { filters:           l.units
                    , activation:        l.activationFunction
                    , kernelSize:        1
                    , inputShape:        inputShape
                    , kernelInitializer: init
                    , biasInitializer:   init
                    , name:              "layer-" + index + "-conv2d"
                    } 

        net.add(tf.layers.conv2d(spec));
      });

      // TODO: Make customisable
      // Final layer
      var init = tf.initializers.randomNormal({ mean: 0, stddev: 1, seed: 1 });
      net.add( tf.layers.conv2d(
        { filters: 3
        , activation: "sigmoid"
        , kernelSize: 1
        , kernelInitializer: init
        , biasInitializer : init
        , name: "final-output"
        } ) );

      return net;
    } );
  }


  /** */
  async startTraining (model) {
    this.training = true;
    this.net.compile({ "optimizer": "adam", "loss": tf.losses.meanSquaredError });

    var elt = document.getElementById("image-to-match");

    function onEpochEnd (epoch, logs) {
      if (epoch % 100 == 0) {
        console.log(epoch, "loss=", logs.loss);
      }

      if( cppn.training === false ){
        cppn.net.stopTraining = true;
      }

      cppn.forward(false);
      app.ports.setEpochs.send(epoch);
    }


    const data = tf.tidy( () => {
      var data = tf.div( tf.browser.fromPixels(elt), tf.scalar(255) );
      data     = tf.expandDims(data, 0);
      return data;
    } );

    const input  = this.buildInput(this.modelSpec.outputWidth, this.modelSpec.outputHeight, this.modelSpec.latentVector);
    const epochs = 1e9;
    const info   = await this.net.fit( input, data, { epochs: epochs, callbacks: { onEpochEnd } });

    this.forward(true);
    const saveResult = await this.net.save("localstorage://cppn-playground");
    tf.dispose(this.net);

    this.net = null;

    tf.disposeVariables();
    tf.dispose(input);
    tf.dispose(data);

    this.net = await tf.loadLayersModel("localstorage://cppn-playground");
  }


  /** */
  randomLatent (n) {
    function getRandomArbitrary (min, max) {
      return Math.random() * (max - min) + min;
    }

    var z = [];

    for ( var i = 0; i < n; i++ ) {
      var zi = getRandomArbitrary(-1, 1);
      z.push(zi);
    }

    return z;
  }


  /** */
  startRandomWalk () {
    const MAX = 100;

    function stepTowards (z1, z2, currentStep) {
      function f () {
        if ( cppn.walking === false ) {
          return;
        }

        if ( currentStep === 0 ) {
          z1 = z2;
          z2 = cppn.randomLatent(cppn.modelSpec.latentDimensions);
          requestAnimationFrame( stepTowards(z1, z2, MAX -1) );
          return;
        }

        var z = [];
        const t = currentStep / MAX;
        for (var i = 0; i < z1.length; i++ ){
          const zi = z1[i] * t + z2[i] * (1-t);
          z.push( zi );
        }

        cppn.modelSpec.latentVector = z;
        app.ports.setLatentVector.send(cppn.modelSpec.latentVector);
        latent.updateCirclePositions(z);
        cppn.forward();
        requestAnimationFrame( stepTowards(z1, z2, currentStep - 1) );
      }

      return f;
    }

    var z1       = this.modelSpec.latentVector;
    var z2       = this.randomLatent(this.modelSpec.latentDimensions);
    this.walking = true;

    requestAnimationFrame( stepTowards(z1, z2, MAX - 1) );
  }


  /** */
  stopRandomWalk () {
    this.walking = false;
    this.forward(true);
  }


  /** */
  downloadBig () {
    tf.tidy( () =>  {
      // Let's only think about squares for now.
      const size    = 1000;
      const allData = this.buildInput(size, size, this.modelSpec.latentVector);

      //  size = 500
      //  |z|  = 10
      //
      // then:
      //  allData.shape = [1, 500, 500, 12];

      const parts = size / this.modelSpec.outputWidth;
      const node  = document.getElementById("big-output");

      for (var i = 0; i < parts; i++) {
        for (var j = 0; j < parts; j++) { 
          var w  = i * this.modelSpec.outputWidth;
          var h  = j * this.modelSpec.outputWidth;
          var wn = (i+1) * this.modelSpec.outputWidth;
          var hn = (j+1) * this.modelSpec.outputWidth;

          var slice = allData.stridedSlice
            ( [0, w, h, 0]
            , [allData.shape[0], wn, hn, allData.shape[allData.shape.length-1]]
            , [1, 1, 1, 1]
            );

          var d = this.net.predict(slice).dataSync();
          this.drawPicture(node, d, this.modelSpec.outputWidth, this.modelSpec.outputWidth, j, i);
        }
      }

      var e = document.getElementById("link");
      e.innerHTML = "";
      var link  = document.createElement("a");
      link.href = node.toDataURL();
      link.download = "cppn-playground-big-image.png";
      e.appendChild(link);
      link.click();

    });
  }
}
