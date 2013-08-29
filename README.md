makelsg
=======

JSON-based question group generator for LimeSurvey

Usage
-----

makelsg [OPTIONS] [JSON]

Options
-------

*   --lang=LANGUAGES

    Specify available languages. Question text, help and answer fields (with optional assessment values) will be read from the JSON file for each of the languages specified in the comma-separated I<LANGUAGES> list and stored in the output XML file. To specify languages, the same language codes used by LimeSurvey are used.

    If the JSON file does not contain definitions for I<all> the specified languages, the script will exit with a warning. The default value is English (I<en>).

*   --gid=GROUP_ID_NUMBER

    Specify the group ID to be stored in the resulting XML file. The default value is 0.

*   --sid=SURVEY_ID_NUMBER

    Specify the survey ID to be stored in the resulting XML file. The default value is 0.

*   --start-qid=ID_NUMBER

    If given, questions will be numbered starting from I<ID_NUMBER>. The default value is 0.

*   -gname GROUP_NAME, --group-name=GROUP_NAME

    Specify the name of the question group. The default value is "Group".

*   -gtext GROUP_DESCRIPTION, --group-text=GROUP_DESCRIPTION

    Provide text for the group description field. The default value is "Group description".

*   --qcode-suffix=SUFFIX

    If given, all question codes in the JSON file will be prepended with I<SUFFIX>. The default value is an empty string.

*   --group-order=ORDER

    Specifies the group order. I'm not actually sure what this does, to be completely honest. Try it at your own risk. The default value is 0.

*   -?, --help

    Show this usage information.

Description
-----------

The script takes as input the structure of a question group in JSON syntax. The options provided to the parser as used in the script make its behaviour quite unforgiving, so as to enforce proper use of the JSON syntax.

Below is an example of the structure expected to be found in the input file:

```javascript
    {
        "questions":[
            {
                "code":"TestQuestion",
                "type":"O",
                "question":{
                    "en":"What does GPL stand for?\nI can use newlines as well.",
                    "es":"¿Qué significa GPL?"
                },
                "help":{
                    "en":"Some help text in English, accepting <span>HTML</span>",
                    "es":"Texto de ayuda en castellano, que soporta <span>HTML</span>"
                },
                "relevance":"1",
                "mandatory":"Y",
                "random_group":"",
                "answers":{
                    "en":[
                        ["General Public License",1],
                        ["Greater Performance Law",0],
                        ["Gone Past Land",0]
                    ],
                    "es":[
                        ["Gone Past Land",0],
                        ["General Public License",1],
                        ["Grande Pero Lento",0]
                    ]
                }
            }
        ]
    }
```

The field `type` holds the code for the question type, which is single-character internal code used by LimeSurvey to differentiate the different types of question. This script has been designed and tested for generating questions of type `L` ("List Drop-Down/Radio-Button List") and `O` ("List With Comment Drop-Down/Radio-Button List"). Other questions might also work, but no guarrantee is given for other types so far.

The answer fields are specified by an array in which the first element is the answer text and the second element is the corresponding assessment value. As shown in the example, these can be different per language.

Future versions will hopefully provide support for more question types.

Version
-------

Version 0.1 -- first public version

Contact
-------

jjatria@gmail.com
