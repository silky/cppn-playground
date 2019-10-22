port module Main exposing (..)

import Printf
import Browser
import Svg exposing (svg)
import Html.Attributes exposing (id
                                , class
                                , for
                                , value
                                , width
                                , height
                                , selected
                                , disabled
                                , src)
import Html exposing (Html, h1, button, div, text, p, label, select, option, h4, span, canvas, sub, img)
import Html.Events exposing (onClick, onInput)
import Dict exposing (Dict)
import Json.Decode as Decode exposing (decodeValue)
import Json.Decode.Pipeline exposing (required, hardcoded)
import Json.Encode as Encode
import Random exposing (Generator)
import Json.Encode.Extra as Encode
import Result exposing (toMaybe)


main =
  Browser.element 
    { init = init
    , view = view
    , update = updateWithStorage
    , subscriptions = \_ -> Sub.batch 
      [ setLatentVector (MaybeSetLatentVector << toMaybe << decodeValue (Decode.list Decode.float))
      , setEpochs       (MaybeSetEpochs       << toMaybe << decodeValue (Decode.int))
      , setCanTrain     (MaybeSetCanTrain     << toMaybe << decodeValue (Decode.bool))
      ]
    }


type alias Layer =
  { units : Int
  , activationFunction : String
  , seed : Float
  }

randomVector : Int -> Generator (List Float)
randomVector n =
  Random.list n (Random.float (-1) 1)


randomLayer : Generator Layer
randomLayer =
  Random.map3 Layer
    (Random.int 1 20)
    (Random.uniform "tanh" allActivationFunctions)
    (Random.float 0 1)


type alias Network =
  { layers : Dict Int Layer
  }


type Colour = Red | Green | Blue

type alias Model =
  { network            : Network
  , outputWidth        : Int
  , outputHeight       : Int
  , walking            : Bool
  , training           : Bool
  , currentEpoch       : Int
  , currentImage       : Maybe String
  , latentDimensions   : Int
  , latentVector       : Maybe (List Float)
  , redNode            : String
  , blueNode           : String
  , greenNode          : String
  , currentlySelecting : Maybe Colour
  , canTrain           : Bool
  }


encodeLayer : Layer -> Decode.Value
encodeLayer l =
  Encode.object
    [ ("units", Encode.int l.units)
    , ("activationFunction", Encode.string l.activationFunction)
    , ("seed", Encode.float l.seed)
    ]

encodeNetwork : Network -> Decode.Value
encodeNetwork net =
    Encode.object
      [ ("layers", Encode.list encodeLayer (Dict.values net.layers))
      ]

encodeModel : Model -> Decode.Value
encodeModel model =
  Encode.object 
    [ ("network", encodeNetwork model.network)
    , ("outputWidth", Encode.int model.outputWidth)
    , ("outputHeight", Encode.int model.outputHeight)
    , ("latentDimensions", Encode.int model.latentDimensions)
    , ("latentVector", Encode.maybe (Encode.list Encode.float) model.latentVector)
    , ("redNode", Encode.string model.redNode)
    , ("greenNode", Encode.string model.greenNode)
    , ("blueNode", Encode.string model.blueNode)
    ]


emptyModel =
  { network = { layers = 
    Dict.fromList
      -- [ (0, Layer 1 "tanh" 0.2)
      -- [ (0, Layer 5 "tanh" 0.2)
      -- , (1, Layer 5 "tanh" 0.3)
      -- , (2, Layer 3 "selu" 0.3)
      [ (0, Layer 20 "tanh" 0.2)
      , (1, Layer 20 "tanh" 0.3)
      , (2, Layer 20 "tanh" 0.4)
      , (3, Layer 20 "tanh" 0.5)
      , (4, Layer 20 "tanh" 0.6)
      , (5, Layer 20 "softsign" 0.7)
      -- Simple
      -- , (5, Layer 10 "relu" 0.2)
      -- , (6, Layer 10 "tanh" 0.3)
      -- , (7, Layer 10 "selu" 0.3)
      -- , (9, Layer 10 "tanh" 0.3)
      ]
    }
  , outputWidth        = 100
  , outputHeight       = 100
  , walking            = False
  , training           = False
  , currentEpoch       = 0
  , latentDimensions   = 10
  , currentImage       = Nothing
  , latentVector       = Nothing
  , redNode            = "final-1"
  , greenNode          = "final-2"
  , blueNode           = "final-3"
  , currentlySelecting = Nothing
  , canTrain           = False
  }


basicLayer = Layer 5 "tanh" 0.4


init : Maybe Decode.Value -> ( Model, Cmd Msg )
init maybeModel =
  -- TODO: Load the model from JSON
  --  Maybe.withDefault emptyModel maybeModel
  ( emptyModel
  , Cmd.batch [ Random.generate SetLatentVector (randomVector emptyModel.latentDimensions)
              -- , resetModel <| encodeModel emptyModel
              ]
  )



port setStorage : Decode.Value -> Cmd msg

port resetModel : Decode.Value -> Cmd msg

port startRandomWalk : Decode.Value -> Cmd msg

port startTraining : Decode.Value -> Cmd msg

port stopTraining : Decode.Value -> Cmd msg

port stopRandomWalk  : Decode.Value -> Cmd msg

port setLatentVector : (Encode.Value -> msg) -> Sub msg

port setEpochs : (Encode.Value -> msg) -> Sub msg

port setCanTrain : (Encode.Value -> msg) -> Sub msg

port downloadBig : () -> Cmd msg

port clearImage : () -> Cmd msg

port rerender : Decode.Value -> Cmd msg



{-| We want to `setStorage` on every update. This function adds the setStorage
    command for every step of the update function.
-}
updateWithStorage : Msg -> Model -> ( Model, Cmd Msg )
updateWithStorage msg model =
    let
        ( newModel, cmds ) =
            update msg model
    in
        ( newModel
        , Cmd.batch [ setStorage (encodeModel model), cmds ]
        )


type Msg = NoOp
         | ModifyLayerUnits      Int Int
         | AddLayer              
         | AddLayerR             Layer
         | ModifyLayerActivation Int String
         | RemoveLayer
         | SetLatentVector       (List Float)
         | MaybeSetLatentVector  (Maybe (List Float))
         | ToggleRandomWalk
         | ToggleTraining
         | MaybeSetEpochs        (Maybe Int)
         | DownloadBig
         | ClearImage
         | SelectRed
         | SelectGreen
         | SelectBlue
         | SetChannel            (Maybe Colour, String)
         | MaybeSetCanTrain      (Maybe Bool)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model = 
  case msg of
    NoOp -> (model, Cmd.none)

    SetChannel (currentlySelecting, ourId) ->
      let
          tempModel = case currentlySelecting of
            Just Red   -> { model | redNode   = ourId }
            Just Green -> { model | greenNode = ourId }
            Just Blue  -> { model | blueNode  = ourId }
            _           -> model
          newModel = { tempModel | currentlySelecting = Nothing } 
      in
        ( newModel , rerender <| encodeModel newModel)

    SelectRed ->
      ( { model | currentlySelecting = Just Red   }, Cmd.none )

    SelectGreen ->
      ( { model | currentlySelecting = Just Green }, Cmd.none )

    SelectBlue ->
      ( { model | currentlySelecting = Just Blue  }, Cmd.none )

    ClearImage ->
      (  { model | canTrain = False } , clearImage () )

    DownloadBig ->
      ( model, downloadBig () )

    MaybeSetCanTrain mct ->
      let
          newModel = { model | canTrain = Maybe.withDefault False mct }
      in
          ( newModel, Cmd.none )

    MaybeSetEpochs me ->
      let
          newModel = Maybe.withDefault model (Maybe.map (\e -> ({ model | currentEpoch = e })) me)
      in
          ( newModel, Cmd.none )

    ToggleTraining ->
      let
       newModel = { model | training = not model.training }
       cmd = if newModel.training then
              startTraining
             else
              stopTraining
      in
        ( newModel, cmd <| encodeModel newModel )

    ToggleRandomWalk ->
      let
       newModel = { model | walking = not model.walking }
       cmd = if newModel.walking then
              startRandomWalk
             else
              stopRandomWalk
      in
        ( newModel, cmd <| encodeModel newModel )

    MaybeSetLatentVector mv ->
      let
          newModel = { model | latentVector = mv }
      in
        ( newModel, Cmd.none )

    SetLatentVector v ->
      let
          newModel = { model | latentVector = Just v }
      in
        ( newModel, resetModel <| encodeModel newModel )

    ModifyLayerActivation index newActivation ->
      let
          f         = Maybe.map (\l -> { l | activationFunction = newActivation })
          newLayers = Dict.update index f model.network.layers
          newModel  = { model | network = { layers = newLayers } }
      in
          ( newModel, resetModel <| encodeModel newModel )
           

    RemoveLayer ->
      let
          minLayers    = 1
          currentCount = Dict.size model.network.layers
          layers       = if currentCount == minLayers then
                           model.network.layers
                         else
                           Dict.remove (currentCount - 1) model.network.layers 
          newModel  = { model | network = { layers = layers } }
      in
          ( newModel, resetModel <| encodeModel newModel )


    AddLayerR newLayer ->
      let
          currentCount = Dict.size model.network.layers
          layers       = Dict.insert currentCount newLayer model.network.layers
          newModel     = { model | network = { layers = layers } }
      in
          ( newModel, resetModel <| encodeModel newModel )


    AddLayer ->
      let
          maxLayers    = 10
          currentCount = Dict.size model.network.layers
          cmd = if currentCount < maxLayers then
                  Random.generate AddLayerR randomLayer
                else
                  Cmd.none
      in
          ( model, cmd )


    ModifyLayerUnits step index ->
      let
          maxNeurons = 20
          minNeurons = 1
          f          = Maybe.map (\l -> { l | units = min (max minNeurons (l.units + step)) maxNeurons })
          newLayers  = Dict.update index f model.network.layers
          newModel   = { model | network = { layers = newLayers } }
      in
          (newModel, resetModel <| encodeModel newModel)


view model =
  div [ id "app" ]
    [ heading
    , topControls model
    , network     model model.network
    ]


heading = 
  div [ class "header" ]
      [ h1 [] [ text "CPPN Playground" ]
      ]

topControls model =
  div [ id "top-controls" ]
    [ div [ class "buttons" ]
          -- [ button [ class "ctl reset" ] [ text "reset" ]
          [ button [ class "ctl train"
                   , onClick ToggleTraining
                   , disabled (not model.canTrain)
                   ]
                  [ text <| if model.training then "stop-training" else "train"  ]

          , button [ class "ctl random-walk"
                  , onClick ToggleRandomWalk
                  , disabled (model.training)
                  ]
                  [ text <| if model.walking then "stop-random-walk" else "random-walk"  ]

          -- , button [ class "ctl random" ] [ text "random network"  ]
          ]
    -- Epoch
    , div [ class "item" ]
          [ label [] [ text "Epoch" ]
          , p [ class "big" ] [ text <| (String.padLeft 10 '0' <| String.fromInt model.currentEpoch)  ]
          ]
    ]


network model net =
  div [ id "network" ]
    [ div [ class "item" ]
          [ inputSection model ]
    -- Hidden Network
    , div [ class "item" ]
          [ hiddenNetwork model ]
    -- Output 
    , div [ class "item" ]
          [ output model ]
    ]

inputSection model =
  let
      xInputs = List.map2 (\a b -> div [ class "input" ] [ a, b ]) 
                  [ span [ id "x1" ] [ text "x", sub [] [ text "1" ] ]
                  , span [ id "x2" ] [ text "x", sub [] [ text "2" ] ]
                  ]
                  (List.map (neuron model (-1)) (List.range 1 2))
      zInput = [ label [ id "z" ] [ text "z" ] -- sub [] [ text "1" ] ]
               , div [] [ svg  [ id "latent-vector" ] [ ] ]
               ]
  in
    div [ class "inputs" ]
      [ h4 [] [ text "Inputs" ]
      , div [ class "layer" ]
        [ div [ class "layer-top" ] [ label [] [ text "Latent vector. Try dragging the circles!" ] ]
        , div [ class "z-input" ] zInput
        ]
      ]

hiddenNetwork model =
  div []
    [ div [ class "row" ]
          [ button [ onClick AddLayer,    class "ctl plus",  disabled model.training ] [ text "+" ]
          , button [ onClick RemoveLayer, class "ctl minus", disabled model.training ] [ text "-" ]
          , h4 [] [ text <| String.fromInt (Dict.size model.network.layers) ++ " Layers" ]
          -- TODO: ???
          -- , button [ class "ctl" ] [ text "randomise network" ]
          ]
    , div [ id "hidden-network" ]
         <| List.map (layer model) (Dict.toList model.network.layers)
    ]

output model =
  let
      last = Dict.size model.network.layers
      selectingClass = 
        case model.currentlySelecting of
          Just Red    -> "red"
          Just Green  -> "green"
          Just Blue   -> "blue"
          Nothing     -> ""
  in
    div []
      [ h4 [] [ text "Output" ]
      , div [ class "layer" ]
            [ div [ class "layer-top" ]
                  [ label [] [ text "Final output"]
                  -- , div [ class "row" ]
                  --       [ neuron_ model "final-1" [ onClick SelectRed   ]
                  --       , neuron_ model "final-2" [ onClick SelectGreen ]
                  --       , neuron_ model "final-3" [ onClick SelectBlue  ]
                  --       ]
                  ]
            --
            , div [ class "neurons"   ]
                  [ finalNeuron model
                  ,  button [ class "ctl", onClick DownloadBig ] [ text "download big version" ] ]
            , div [ id "paste", class "neurons" ] [ label [] [ text "Paste an image!" ] ]
            , div [ id "input-image" ]
              --
              [ label [] [ text "Input image" ] 
              , div [ class "img-thingy"] 
                  [ img [ id "uploaded-image"
                        , width model.outputWidth
                        , height model.outputHeight
                        ] [] 

                  , label [] [ text "Image to match!" ]
                  , div [ id "actual-image-container" ] []
                  ]
              , button [ class "ctl", onClick ClearImage, disabled model.training ] [ text "clear" ]
              ]
            ]
      ]

allActivationFunctions = List.sort 
              [ "tanh"
              , "relu"
              , "selu"
              , "elu"
              , "relu6"
              , "softmax"
              , "softplus"
              , "softsign"
              ]

activationFunctions model current c
  = let
      mkOpt f = option [ value f, selected (current == f)] [ text f ]
    in
      select [ onInput c
             , disabled model.training
             ] <| List.map mkOpt allActivationFunctions


layer : Model -> (Int, Layer) -> Html Msg
layer model (index, l) =
  div [ class "layer" ]
      [ div [ class "layer-top" ]
            [ div [ class "row" ]
                [ button [ onClick (ModifyLayerUnits ( 1) index), class "ctl plus",  disabled model.training ] [ text "+" ]
                , button [ onClick (ModifyLayerUnits (-1) index), class "ctl minus", disabled model.training ] [ text "-" ]
                ]
            , label [] [text <| String.fromInt (l.units) ++ " filters" ]
            , activationFunctions model l.activationFunction (ModifyLayerActivation index)
            ]
      , div [ class "neurons" ]
            <| List.map (neuron model index) (List.range 1 l.units)
      ]


finalNeuron : Model -> Html Msg
finalNeuron  model
  = canvas
      [ width  model.outputWidth
      , height model.outputHeight
      , id <| "final-neuron" ] []


neuron_ : Model -> String -> List (Html.Attribute Msg) -> Html Msg
neuron_ model ourId attrs 
  = let
      size = 20

      ourClass =
        if ourId == model.redNode then
          "red"
        else
          if ourId == model.greenNode then
            "green"
          else
            if ourId == model.blueNode then
              "blue"
            else ""

      selectingClass = 
        case model.currentlySelecting of
          Just Red    -> "pick-red"
          Just Green  -> "pick-green"
          Just Blue   -> "pick-blue"
          Nothing     -> ""

      attr = onClick <| SetChannel (model.currentlySelecting, ourId)
      --
      -- If we're currently selecting; then we have a _click_ action to
      -- pick the current one.
      --
      ourAttrs = Maybe.withDefault
                  attrs 
                  (Maybe.map (\_ -> attr :: attrs) model.currentlySelecting)
    in
      canvas (
        [ width  size
        , height size
        , class selectingClass
        , class ourClass
        , id ourId
        ] ++ ourAttrs)
        []

neuron : Model -> Int -> Int -> Html Msg
neuron model layerNumber neuronNumber
  = neuron_
      model
      (String.fromInt layerNumber ++ "-" ++ String.fromInt neuronNumber)
      []

-- TODO:
--  Latent vectors
--    [x] Display them
--    [x] Edit them
--    - Interpolate
--
--  Matching
--    [x] Input an image to match
--    [x] Allow user to pick image
--
--  Initialisation?
--    - Different ones?
--
--  Colour space
--    - ???
--    - In general, make output layer customisable
--    - Allow for colour palettes
--
--  Save in URL
--
--  Inputs
--    - Make them toggleable
--    - Norms
--    - Try polar-coordinates intstead of x, y?
--
--  3D
--    - Infinite 3D shape.
--
--
-- Add in HSIC?!?!?!
--  Mutual information stuffs?!?! 
