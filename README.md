# [CPPN Playground](https://silky.github.io/cppn-playground/)

![](/images/cppn-playground.jpg)


### Dev

To compile the Elm:

```
make devel
```

Then, run a webserver in the `./dist` directory. For example,

```
python3 -m http.server 8003
```

### TODO

Latent vectors

- [x] Display them
- [x] Edit them
- [ ] Interpolate

Matching

- [x] Input an image to match
- [x] Allow user to pick image

Initialisation

- [ ] Different ones
- [ ] Reset it

Colour space

- [ ] Allow varying it
- [ ] In general, make output layer customisable
- [ ] Allow for colour palettes

General

- [ ] Save in URL
- [ ] Save an animation
- [ ] Good explanation of what's going on

Inputs

- [ ] Make them toggleable
- [ ] Norms
- [ ] Try polar-coordinates intstead of x, y?

Outputs

- [ ] Allow selecing different intermediate nodes
- [ ] Plot the loss, when training

3D

- [ ] Infinite 3D shape.

Misc

- [ ] Add in [HSIC](https://arxiv.org/pdf/1908.01580.pdf)
