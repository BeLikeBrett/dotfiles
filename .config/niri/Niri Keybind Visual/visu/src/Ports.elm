port module Ports exposing (receiveParsed, saveNotes, sendConfig)

import Json.Decode as Decode
import Json.Encode as Encode


port sendConfig : String -> Cmd msg


port receiveParsed : (Decode.Value -> msg) -> Sub msg


port saveNotes : Encode.Value -> Cmd msg
