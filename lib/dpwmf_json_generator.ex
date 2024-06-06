defmodule DpwmfJsonGenerator do
  alias Constants
  @moduledoc """
  Make json out of a piece
  """
  @input_file "./data/inputs/input"
  @output_file "./data/outputs/output.json"
  def jsonify(filepath \\ @input_file) do
    filepath
    |> read_file()
    |> parse_file()
    |> make_json()
    |> put_to_file()
  end

  def read_file(filename), do: File.read(filename)

  def parse_file({:ok, file_content}) do
    file_content
    |> split_by_strings()
    |> Enum.map(&parse_string/1)
  end

  def split_by_strings(strings), do: String.split(strings, ~r{(\r\n|\r|\n)}, trim: true)

  def parse_string(string) do
    string
    |> fetch_choice()
    |> fetch_precondition()
    |> fetch_speaker()
    |> fetch_emotion()
    |> add_all_characters()
  end

  def fetch_choice("[" <> tail) do
    choices = tail
    |> String.replace("]", "")
    |> String.split("& ")
    %{choice: true, speech: choices}
  end
  def fetch_choice(string), do: %{speech: string}

  def fetch_precondition(%{choice: true} = string), do: string
  def fetch_precondition(%{speech: speech} = string) do
    case String.at(speech, 3) do
      "]" -> string
      |> Map.put(:speech, String.replace(speech, ~r{\d\.\d] }, ""))
      |> Map.put(:precondition, {String.at(speech, 0), String.at(speech, 2)})
      _ -> string
    end
  end

  def fetch_speaker(%{choice: true} = string), do: Map.put(string, :speaker, Constants.default_speaker)

  def fetch_speaker(%{speech: speech} = string) do
    case :binary.match(speech, ": ") do
      :nomatch -> Map.put(string, :speaker, Constants.default_speaker)
      {_, _} ->
        [speaker, speech] = String.split(speech, ": ")
        speaker = Map.fetch!(Constants.name_translations, String.downcase(speaker))
        string
        |> Map.put(:speaker, speaker)
        |> Map.put(:speech, speech)
    end
  end

  def fetch_emotion(%{choice: true} = string), do: string
  def fetch_emotion(%{speech: speech, speaker: speaker} = string) do
    cond do
      String.at(speech, 0) == "(" ->
        "(" <> tail = speech
        [emotion, speech] = tail
        |> String.split(") ", parts: 2)
        emotion = Constants.emotions_all
        |> Map.fetch!(speaker)
        |> Map.fetch!(emotion)

        string
        |> Map.put(:emotion, emotion)
        |> Map.put(:speech, speech)
      true -> string
    end
    |> filter_default_emotion()
    |> add_emotion_prefix()
  end

  def filter_default_emotion(%{speaker: speaker, emotion: emotion} = string) do
    cond do
      emotion == Map.fetch!(Constants.default_emotions, speaker) ->
        Map.delete(string, :emotion)
      true -> string
    end
  end
  def filter_default_emotion(string), do: string

  def add_emotion_prefix(%{speaker: speaker, emotion: emotion} = string) do
    cond do
      !!Constants.emotions_prefixes[speaker] ->
        Map.put(string, :emotion, Constants.emotions_prefixes[speaker] <> emotion)
      true -> string
    end
  end
  def add_emotion_prefix(string), do: string

  def add_all_characters(%{speaker: speaker} = string) do
    characters = Enum.map(Constants.characters, fn c -> {c, _character_data(c, speaker)} end)
    string
    |> Map.put(:characters, characters)
    |> Map.delete(:speaker)
  end

  def _character_data(character, speaker) when character == speaker, do: [speaker: true]
  def _character_data(_, _), do: %{}


  def make_json(parsed_file) do
    {:ok, json} = JSON.encode(parsed_file)
    json
  end

  def put_to_file(json_data, path \\ @output_file) do
    File.write(path, json_data)
  end
end
