#!/usr/bin/perl

use warnings;
use diagnostics;
use strict;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case);
use JSON -support_by_pp;

sub LoadTemplates ();
# sub PopulateTemplates (@);
# sub GroupsAndLanguages ();
# sub QuestionsAndAnswers (@);

my %OPTIONS;
GetOptions (
    \%OPTIONS,
    'lang=s@',
    'gid=i',
    'sid=i',
    'group-name|gname=s',
    'qcode-suffix=s',
    'group-order|gorder=s',
    'group-text|gtext=s',
    'start-qid=i',
    'help|?',
);

if (defined $OPTIONS{lang} && $OPTIONS{lang}->[0] ne '') {
    @{$OPTIONS{lang}} = split(/,/, (join ',', @{$OPTIONS{lang}}));
} else {
    $OPTIONS{lang} = [('en')];
}
$OPTIONS{'qcode-suffix'} = $OPTIONS{'qcode-suffix'} // '';
$OPTIONS{'group-name'}   = $OPTIONS{'group-name'}   // 'Group';
$OPTIONS{'group-text'}   = $OPTIONS{'group-text'}   // 'Group description';
$OPTIONS{'group-order'}  = $OPTIONS{'group-order'}  // 0;
$OPTIONS{'sid'}          = $OPTIONS{'sid'}          // 0;
$OPTIONS{'gid'}          = $OPTIONS{'gid'}          // 0;

my %TEMPLATES = LoadTemplates();

sub PopulateTemplates {
    my $output = $TEMPLATES{body};

    $output = GroupsAndLanguages(\$output);
    $output = QuestionsAndAnswers(\$output, @_);

    chomp $output;
    return $output;
}

sub GroupsAndLanguages {
    my $output = ${shift @_};

    my $LANGUAGE_ROWS = '';
    my $GROUP_ROWS    = '';

    foreach (@{$OPTIONS{lang}}) {
        $LANGUAGE_ROWS .=  $TEMPLATES{language};
        $LANGUAGE_ROWS  =~ s/__LANG__/$_/;

        $GROUP_ROWS .=  $TEMPLATES{group};
        $GROUP_ROWS  =~ s/__SID__/$OPTIONS{'sid'}/;
        $GROUP_ROWS  =~ s/__GID__/$OPTIONS{'gid'}/;
        $GROUP_ROWS  =~ s/__GNAME__/$OPTIONS{'group-name'}/;
        $GROUP_ROWS  =~ s/__GORDER__/$OPTIONS{'group-order'}/;
        $GROUP_ROWS  =~ s/__GTEXT__/$OPTIONS{'group-text'}/;
        $GROUP_ROWS  =~ s/__LANG__/$_/;
    }

    chomp $LANGUAGE_ROWS;
    chomp $GROUP_ROWS;
    $output =~ s/__LANGUAGES__/$LANGUAGE_ROWS/;
    $output =~ s/__GROUPS__/$GROUP_ROWS/;
    
#     print $output;

    return $output;
}

sub QuestionsAndAnswers {
    my $output = ${shift @_};
    my @questions = @_;

    my $QUESTION_ROWS  = '';
    my $ANSWER_ROWS    = '';
    my $ATTRIBUTE_ROWS = '';

    my $qid = 0;
    foreach my $q (@questions) {
        $qid++;
        $qid +=  $OPTIONS{'start-qid'} if (defined $OPTIONS{'start-qid'});

        $ATTRIBUTE_ROWS .=  $TEMPLATES{attributes};
        $ATTRIBUTE_ROWS  =~ s/__QID__/$qid/g;
        $ATTRIBUTE_ROWS  =~ s/__RANDGROUP__/$q->{random_group}/g;

        foreach my $lang (@{$OPTIONS{lang}}) {
            $QUESTION_ROWS .=  $TEMPLATES{question};

            $QUESTION_ROWS  =~ s/__QTEXT__/$q->{question}->{$lang}/;
            $QUESTION_ROWS  =~ s/__QID__/$qid/;
            $QUESTION_ROWS  =~ s/__GID__/$OPTIONS{'gid'}/;
            $QUESTION_ROWS  =~ s/__SID__/$OPTIONS{'sid'}/;
            $QUESTION_ROWS  =~ s/__QCODE__/$q->{code}/;
            $QUESTION_ROWS  =~ s/__QHELP__/$q->{help}->{$lang}/;
            $QUESTION_ROWS  =~ s/__QTYPE__/$q->{type}/;
            $QUESTION_ROWS  =~ s/__QMANDATORY__/$q->{mandatory}/;
            $QUESTION_ROWS  =~ s/__LANG__/$lang/;
            $QUESTION_ROWS  =~ s/__RELEVANCE__/$q->{relevance}/;

            my $acode = 0;
            foreach my $a (@{$q->{answers}->{$lang}}) {
                $acode++;
                $ANSWER_ROWS .=  $TEMPLATES{answer};
                $ANSWER_ROWS  =~ s/__QID__/$qid/;
                $ANSWER_ROWS  =~ s/__ACODE__/$acode/;
                $ANSWER_ROWS  =~ s/__ASSESSMENT__/$a->[1]/;
                $ANSWER_ROWS  =~ s/__ATEXT__/$a->[0]/;
                $ANSWER_ROWS  =~ s/__ASORT__/$acode+1/e;
                $ANSWER_ROWS  =~ s/__LANG__/$lang/;
            }
        }
    }
    chomp $QUESTION_ROWS;
    chomp $ATTRIBUTE_ROWS;
    chomp $ANSWER_ROWS;
    $output =~ s/__QUESTIONS__/$QUESTION_ROWS/;
    $output =~ s/__ATTRIBUTES__/$ATTRIBUTE_ROWS/;
    $output =~ s/__ANSWERS__/$ANSWER_ROWS/;

    return $output;
}

sub CheckLanguages {
    my $ret = 1;
    my $q = shift @_;
    my @langs = sort @{$OPTIONS{lang}};
    my @q = sort keys %{$q->{question}};
    my @a = sort keys %{$q->{answers}};
    my @h = sort keys %{$q->{help}};
    foreach (@langs) {
        my $r = 1;
        $r = 0 unless exists ($q->{question}->{$_});
        $r = 0 unless exists ($q->{answers}->{$_});
        $r = 0 unless exists ($q->{help}->{$_});
        print STDERR "E: $q->{code} missing definition for $_. Check input\n" unless $r;
        $ret = 0 unless $r;
    }
    return $ret;
}

sub ParseJSONSurvey {
    my $filename = shift @_;
    my @questions;
    my $sanity_check = 1;
    my %question_codes;
    eval {
        my $fh;
        open $fh, $filename
            or die "Could not open $fh: $!";
        my $content = do { local $/;  <$fh> };
        my $json = new JSON->decode($content);

        foreach my $q (@{$json->{questions}}) {
            my %h = (
                question     => $q->{question},
                relevance    => $q->{relevance} // 1,
                random_group => $q->{random_group},
                answers      => $q->{answers},
                type         => $q->{type},
                help         => $q->{help},
                mandatory    => $q->{mandatory},
                code         => $q->{code} . $OPTIONS{'qcode-suffix'},
            );
            $sanity_check = 0 unless CheckLanguages(\%h);
            $question_codes{$q->{code}}++;
            push @questions, \%h;
        }
    };
    # Catch
    if ($@) {
        print STDERR "E: JSON parser crashed! $@\n";
    }
    exit(1) unless $sanity_check;
    foreach (sort keys %question_codes) {
        if ($question_codes{$_} > 1) {
            print STDERR "E: Non unique question codes ($_). Check input.\n";
            exit(1);
        }
    }
    return reverse @questions;
}

my @questions = ParseJSONSurvey($ARGV[0]);
my $GROUPXML  = PopulateTemplates(@questions);

print "$GROUPXML\n";

sub LoadTemplates () {
    my %t;

$t{body} = <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<document>
 <LimeSurveyDocType>Group</LimeSurveyDocType>
 <DBVersion>155</DBVersion>
 <languages>
__LANGUAGES__
 </languages>
 <groups>
  <fields>
   <fieldname>gid</fieldname>
   <fieldname>sid</fieldname>
   <fieldname>group_name</fieldname>
   <fieldname>group_order</fieldname>
   <fieldname>description</fieldname>
   <fieldname>language</fieldname>
   <fieldname>randomization_group</fieldname>
   <fieldname>grelevance</fieldname>
  </fields>
  <rows>
__GROUPS__
  </rows>
 </groups>
 <questions>
  <fields>
   <fieldname>qid</fieldname>
   <fieldname>parent_qid</fieldname>
   <fieldname>sid</fieldname>
   <fieldname>gid</fieldname>
   <fieldname>type</fieldname>
   <fieldname>title</fieldname>
   <fieldname>question</fieldname>
   <fieldname>preg</fieldname>
   <fieldname>help</fieldname>
   <fieldname>other</fieldname>
   <fieldname>mandatory</fieldname>
   <fieldname>question_order</fieldname>
   <fieldname>language</fieldname>
   <fieldname>scale_id</fieldname>
   <fieldname>same_default</fieldname>
   <fieldname>relevance</fieldname>
  </fields>
  <rows>
__QUESTIONS__
  </rows>
 </questions>
 <answers>
  <fields>
   <fieldname>qid</fieldname>
   <fieldname>code</fieldname>
   <fieldname>answer</fieldname>
   <fieldname>assessment_value</fieldname>
   <fieldname>sortorder</fieldname>
   <fieldname>language</fieldname>
   <fieldname>scale_id</fieldname>
  </fields>
  <rows>
__ANSWERS__
  </rows>
 </answers>
 <question_attributes>
  <fields>
   <fieldname>qid</fieldname>
   <fieldname>attribute</fieldname>
   <fieldname>value</fieldname>
  </fields>
  <rows>
__ATTRIBUTES__
  </rows>
 </question_attributes>
</document>
EOF

$t{language} = <<'EOF';
  <language>__LANG__</language>
EOF

$t{group} = <<'EOF';
   <row>
    <gid><![CDATA[__GID__]]></gid>
    <sid><![CDATA[__SID__]]></sid>
    <group_name><![CDATA[__GNAME__]]></group_name>
    <group_order><![CDATA[__GORDER__]]></group_order>
    <description><![CDATA[__GTEXT__]]></description>
    <language><![CDATA[__LANG__]]></language>
    <randomization_group><![CDATA[]]></randomization_group>
    <grelevance><![CDATA[]]></grelevance>
   </row>
EOF

$t{attributes} = <<'EOF';
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[alphasort]]></attribute>
    <value><![CDATA[0]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[array_filter]]></attribute>
    <value><![CDATA[]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[array_filter_exclude]]></attribute>
    <value><![CDATA[]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[display_columns]]></attribute>
    <value><![CDATA[1]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[hidden]]></attribute>
    <value><![CDATA[0]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[hide_tip]]></attribute>
    <value><![CDATA[0]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[other_comment_mandatory]]></attribute>
    <value><![CDATA[0]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[other_numbers_only]]></attribute>
    <value><![CDATA[0]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[other_replace_text]]></attribute>
    <value><![CDATA[]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[page_break]]></attribute>
    <value><![CDATA[0]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[public_statistics]]></attribute>
    <value><![CDATA[0]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[random_group]]></attribute>
    <value><![CDATA[__RANDGROUP__]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[random_order]]></attribute>
    <value><![CDATA[0]]></value>
   </row>
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <attribute><![CDATA[scale_export]]></attribute>
    <value><![CDATA[0]]></value>
   </row>
EOF

$t{question} = <<'EOF';
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <parent_qid><![CDATA[0]]></parent_qid>
    <sid><![CDATA[__SID__]]></sid>
    <gid><![CDATA[__GID__]]></gid>
    <type><![CDATA[__QTYPE__]]></type>
    <title><![CDATA[__QCODE__]]></title>
    <question><![CDATA[__QTEXT__]]></question>
    <preg><![CDATA[]]></preg>
    <help><![CDATA[__QHELP__]]></help>
    <other><![CDATA[N]]></other>
    <mandatory><![CDATA[__QMANDATORY__]]></mandatory>
    <question_order><![CDATA[2]]></question_order>
    <language><![CDATA[__LANG__]]></language>
    <scale_id><![CDATA[0]]></scale_id>
    <same_default><![CDATA[0]]></same_default>
    <relevance><![CDATA[__RELEVANCE__]]></relevance>
   </row>
EOF

$t{answer} = <<'EOF';
   <row>
    <qid><![CDATA[__QID__]]></qid>
    <code><![CDATA[__ACODE__]]></code>
    <answer><![CDATA[__ATEXT__]]></answer>
    <assessment_value><![CDATA[__ASSESSMENT__]]></assessment_value>
    <sortorder><![CDATA[__ASORT__]]></sortorder>
    <language><![CDATA[__LANG__]]></language>
    <scale_id><![CDATA[0]]></scale_id>
   </row>
EOF

    return %t;
}


# GetOptions (
#     \%OPTIONS,
#     'help|?',
# );


=head1 NAME

makelsg - JSON-based question group generator for LimeSurvey

=head1 SYNOPSIS

makelsg [OPTIONS] [JSON]

=head1 OPTIONS

=over 8

=item B<--lang>=I<LANGUAGES>

Specify available languages. Question text, help and answer fields (with optional assessment values) will be read from the JSON file for each of the languages specified in the comma-separated I<LANGUAGES> list and stored in the output XML file. To specify languages, the same language codes used by LimeSurvey are used.

If the JSON file does not contain definitions for I<all> the specified languages, the script will exit with a warning. The default value is English (I<en>).

=item B<--gid>=I<GROUP_ID_NUMBER>

Specify the group ID to be stored in the resulting XML file. The default value is 0.

=item B<--sid>=I<SURVEY_ID_NUMBER>

Specify the survey ID to be stored in the resulting XML file. The default value is 0.

=item B<--start-qid>=I<ID_NUMBER>

If given, questions will be numbered starting from I<ID_NUMBER>. The default value is 0.

=item B<-gname> I<GROUP_NAME>, B<--group-name>=I<GROUP_NAME>

Specify the name of the question group. The default value is "Group".

=item B<-gtext> I<GROUP_DESCRIPTION>, B<--group-text>=I<GROUP_DESCRIPTION>

Provide text for the group description field. The default value is "Group description".

=item B<--qcode-suffix>=I<SUFFIX>

If given, all question codes in the JSON file will be prepended with I<SUFFIX>. The default value is an empty string.

=item B<--group-order>=I<ORDER>

Specifies the group order. I'm not actually sure what this does, to be completely honest. Try it at your own risk. The default value is 0.

=item B<-?>, B<--help>

Show this usage information.

=back

=head1 DESCRIPTION

The script takes as input the structure of a question group in JSON syntax. The options provided to the parser as used in the script make its behaviour quite unforgiving, so as to enforce proper use of the JSON syntax.

Below is an example of the structure expected to be found in the input file:

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

The field I<type> holds the code for the question type, which is single-character internal code used by LimeSurvey to differentiate the different types of question. This script has been designed and tested for generating questions of type I<L> ("List Drop-Down/Radio-Button List") and I<O> ("List With Comment Drop-Down/Radio-Button List"). Other questions might also work, but no guarrantee is given for other types so far.

The answer fields are specified by an array in which the first element is the answer text and the second element is the corresponding assessment value. As shown in the example, these can be different per language.

Future versions will hopefully provide support for more question types.

=head1 VERSION

Version 0.1 -- first public version

=head1 AUTHOR

Jose Joaquin Atria <jjatria@gmail.com>
