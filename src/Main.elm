port module Main exposing (..)

import Browser
import Html.Attributes exposing (id, class, for, value, width, height, selected)
import Html exposing (Html, h1, button, div, text, p, label, select, option, h4, span, canvas, sub)
import Html.Events exposing (onClick, onInput)
import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Decode.Pipeline exposing (required, hardcoded)
import Json.Encode as Encode
import Random exposing (Generator)


main =
  Browser.element 
    { init = init
    , view = view
    , update = updateWithStorage
    , subscriptions = \_ -> Sub.none
    }


type alias Layer =
  { units : Int
  , activationFunction : String
  , seed : Float
  }


randomLayer : Generator Layer
randomLayer =
  Random.map3 Layer
    (Random.int 1 20)
    (Random.uniform "tanh" allActivationFunctions)
    (Random.float 0 1)


type alias Network =
  { layers : Dict Int Layer
  }

type alias Model =
  { network      : Network
  , outputWidth  : Int
  , outputHeight : Int
  , redNode      : Maybe String
  , blueNode     : Maybe String
  , greenNode    : Maybe String
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
    ]


emptyModel =
  { network = { layers = 
    Dict.fromList
      -- [ (0, Layer 3 "tanh" 0.2)
      -- , (1, Layer 5 "tanh" 0.3)
      [ (0, Layer 11 "relu" 0.2)
      , (1, Layer 12 "tanh" 0.3)
      ]
    }
    -- TODO: Make a parameter
  , outputWidth  = 200
  , outputHeight = 200
  , redNode      = Nothing
  , blueNode     = Nothing
  , greenNode    = Nothing
  }


basicLayer = Layer 5 "tanh" 0.4


init : Maybe Decode.Value -> ( Model, Cmd Msg )
init maybeModel =
  -- TODO: Load the model from JSON
  -- ( Maybe.withDefault emptyModel maybeModel
  ( emptyModel
  , resetModel <| encodeModel emptyModel
  )



port setStorage : Decode.Value -> Cmd msg


port resetModel : Decode.Value -> Cmd msg


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
         -- | ModifyLayers          Int
         | AddLayer              
         | AddLayerR             Layer
         | ModifyLayerActivation Int String
         | RemoveLayer


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model = 
  case msg of
    NoOp -> (model, Cmd.none)

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
    , topControls model.network
    , network     model.network
    ]


heading = 
  div [ class "header" ]
      [ h1 [] [ text "CPPN Playground" ]
      ]

topControls net =
  div [ id "top-controls" ]
    [ div [ class "buttons" ]
          [ button [ class "ctl reset"        ] [ text "reset" ]
          , button [ class "ctl play"         ] [ text "play"  ]
          , button [ class "ctl step-forward" ] [ text "step"  ]
          ]
    -- Epoch
    , div [ class "item" ]
          [ label [] [ text "Epoch" ]
          , p [ class "big" ] [ text "000,000" ]
          ]
    ]


network net =
  div [ id "network" ]
    [ div [ class "item" ]
          [ inputSection ]
    -- Hidden Network
    , div [ class "item" ]
          [ hiddenNetwork net ]
    -- Output 
    , div [ class "item" ]
          [ output net ]
    ]

inputSection =
  div [ class "inputs" ]
    [ h4 [] [ text "Inputs" ]
    , div [ class "layer" ]
      [ div [ class "layer-top" ] [ label [] [ text "Which properties do you want to feed in?" ] ]
      , div [ class "neurons" ]
          <| List.map2 (\a b -> div [ class "input" ] [ a, b ]) 
                [ span [] [ text "x", sub [] [ text "1" ] ]
                , span [] [ text "x", sub [] [ text "2" ] ]
                ]
                (List.map (neuron (-1)) (List.range 1 2))
      ]
    ]

hiddenNetwork net =
  div []
    [ div [ class "row" ]
          [ button [ onClick AddLayer,    class "ctl plus"  ] [ text "+" ]
          , button [ onClick RemoveLayer, class "ctl minus" ] [ text "-" ]
          , h4 [] [ text <| String.fromInt (Dict.size net.layers) ++ " Layers" ]
          ]
    , div [ id "hidden-network" ]
         <| List.map (layer net) (Dict.toList net.layers)
    ]

output net =
  div []
    [ h4 [] [ text "Output" ]
    , div [ class "layer" ]
          [ div [ class "layer-top" ] [ label [] [ text "Final output"] ]
          , div [ class "neurons"   ] [ finalNeuron ]
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

activationFunctions current c
  = let
      mkOpt f = option [ value f, selected (current == f)] [ text f ]
    in
      select [ onInput c ] <| List.map mkOpt allActivationFunctions


layer : Network -> (Int, Layer) -> Html Msg
layer net (index, l) =
  div [ class "layer" ]
      [ div [ class "layer-top" ]
            [ div [ class "row" ]
                [ button [ onClick (ModifyLayerUnits ( 1) index), class "ctl plus"  ] [ text "+" ]
                , button [ onClick (ModifyLayerUnits (-1) index), class "ctl minus" ] [ text "-" ]
                ]
            , label [] [text <| String.fromInt (l.units) ++ " filters" ]
            , activationFunctions l.activationFunction (ModifyLayerActivation index)
            ]
      , div [ class "neurons" ]
            <| List.map (neuron index) (List.range 1 l.units)
      ]


finalNeuron : Html Msg
finalNeuron 
  = canvas
      [ width  200
      , height 200
      , id <| "final-neuron" ] []


neuron : Int -> Int -> Html Msg
neuron layerNumber neuronNumber
  = let
      size = 30
    in
      canvas
        [ width  size
        , height size
        , id <| String.fromInt layerNumber ++ "-" ++ String.fromInt neuronNumber ] []

-- TODO:
--  Latent vectors
--    - Display them
--    - Edit them
--    - Interpolate
--
--  Matching
--    - Input an image to match
--
--  Initialisation?
--    - Different ones?
--
--  Colour space
--    - ???
--    - In general, make output layer customisable
--
--  Save in URL
