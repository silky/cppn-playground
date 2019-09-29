function resetModel (newModel) {
  var h    = newModel.outputHeight;
  var w    = newModel.outputWidth;
  var zdim = 0;
  
  // 1. Build model
  var model = buildModel(newModel, w, h, zdim);

  // 2. Build input
  z = tf.randomNormal([zdim]); 
  var data = buildInput(w, h, z);

  // 3. Push it through the network
  var outputNames = []

  for (var i = 0; i <= newModel.network.layers.length; i++) {
    var name = model.getLayer( undefined, i ).output.name;
    outputNames.push( name );
  }

  outputs = model.execute(data, outputNames);
  result  = outputs[outputs.length - 1]

  // 4. Render all the intermediate neurons
  var l = 0;
  outputs.slice(0, outputs.length - 1).forEach( output => {
    var lastShape = output.shape[3];

    for (var i = 0; i < lastShape; i++) {
      var newShape = [output.shape[0], output.shape[1], output.shape[2], i + 1];
      var chunk    = output.stridedSlice( [0, 0, 0, i], newShape, [1, 1, 1, 1]);

      chunk = tf.image.resizeBilinear(chunk, [30, 30]);
      chunk = tf.sigmoid( tf.squeeze( chunk ) );

      var nodeId = l + "-" + (i+1)
      var node   = document.getElementById(nodeId);

      tf.browser.toPixels(chunk, node);
    }

    l += 1;
  });

  // 5. Render it in the final neuron
  var node = document.getElementById("final-neuron");
  tf.browser.toPixels( tf.squeeze(result), node );
}


function buildInput (w, h, z) {
  x = tf.linspace(-1, 1, w);
  y = tf.linspace(-1, 1, h);

  const xx = tf.matMul( tf.ones  ([h, 1]), x.reshape([1, w]) )
  const yy = tf.matMul( y.reshape([h, 1]), tf.ones  ([1, w]) );

  var data   = tf.stack( [xx, yy], -1 );

  // Add in the "z" stuff.
  const ones = tf.ones( [ w, h, 1] );
  data       = tf.concat( [data, tf.mul(ones, z)], 2 );

  // Add in batch dimension. Note, for some 
  // reason, the batch dimension is at the front.
  data = data.reshape( [1].concat( data.shape ) );
  return data;
}


function buildModel (newModel, w, h, zdim) {

  function buildConvnetModel () {
    const model = tf.sequential();
    var  first  = true;
    var  index  = 0;

    newModel.network.layers.forEach( l => {
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

      model.add(tf.layers.conv2d(spec));
    });

    // TODO: Make customisable
    // Final layer
    var init = tf.initializers.randomNormal({ mean: 0, stddev: 1, seed: 1 });
    model.add( tf.layers.conv2d(
      { filters: 3
      , activation: "sigmoid"
      , kernelSize: 1
      , kernelInitializer: init
      , biasInitializer : init
      , name: "final-output"
      } ) );

    return model;
  } 

  return buildConvnetModel();
}
