class LatentCanvas {
  constructor () {
    this.width  = 100;
    this.height = 100;
    this.radius = 5;
    this.cx     = this.width / 2;
    this.cy     = this.height / 2;
    this.maxR   = 35;
    this.svg    = null;
  }


  /** */
  initialiseLatentVector () {
    this.svg = d3.select("#latent-vector");
    function dragstarted(d) {
      d3.select(this).raise().attr("stroke", "black");
    }

    function dragended(d) {
      d3.select(this).attr("stroke", null);
      cppn.forward(true);
      app.ports.setLatentVector.send(cppn.modelSpec.latentVector);
    }

    function makeDragged (dimensions) {
      function dragged(d) {
        // TODO: There's a problem with quadrants; but let's address that another
        // day.
        
        // Project it onto the line.
        var r      = Math.sqrt( (d3.event.x - latent.cx) ** 2 + (d3.event.y - latent.cy) **2 );
        const psi  = d.i * 2 * Math.PI / dimensions;
        const minR = 0;
        r          = Math.max(Math.min(r, latent.maxR), minR);

        const data = {
          x: latent.cx + r * Math.cos(psi),
          y: latent.cy + r * Math.sin(psi),
        };

        cppn.modelSpec.latentVector[d.i] = (r / latent.maxR) * 2 - 1;
        d3.select(this).attr("cx", d.x = data.x).attr("cy", d.y = data.y);
        cppn.forward();
        app.ports.setLatentVector.send(cppn.modelSpec.latentVector);
      }

      return dragged;
    }

    const dimensions = cppn.modelSpec.latentVector.length;

    const drag = d3.drag()
        .on("start", dragstarted)
        .on("drag",  makeDragged(dimensions))
        .on("end",   dragended);

    const circles = d3.range(dimensions).map(i => function () {
        // z[i] ranges from -1 to 1.
        var norm = (1 + cppn.modelSpec.latentVector[i])/2;
        var scale = latent.maxR * norm;
        var data = {
          x: latent.cx + scale * Math.cos(i * 2 * Math.PI / dimensions),
          y: latent.cy + scale * Math.sin(i * 2 * Math.PI / dimensions),
          i: i,
        }
        return data;
      }()
    );

    this.svg.selectAll("circle")
      .data(circles)
      .join("circle")
        .attr("cx", d => d.x)
        .attr("cy", d => d.y)
        .attr("r", this.radius)
        .attr("fill", (d) => d3.schemeCategory10[d.i % 10])
        .call(drag);
  }

  updateCirclePositions (z) {
    var circles = this.svg.selectAll("circle");

    circles
      .attr("cx", function (d) {
        const norm  = (1 + z[d.i])/2;
        const scale = latent.maxR * norm;
        const x     = latent.cx + scale * Math.cos(d.i * 2 * Math.PI / cppn.modelSpec.latentVector.length);
        return x;
      })
      .attr("cy", function (d) {
        const norm  = (1 + z[d.i])/2;
        const scale = latent.maxR * norm;
        const y     = latent.cy + scale * Math.sin(d.i * 2 * Math.PI / cppn.modelSpec.latentVector.length);
        return y;
      })
    ;
  }
}




