
;    Copyright 2013 Christopher Kotfila
; 
;    Licensed under the Apache License, Version 2.0 (the "License");
;    you may not use this file except in compliance with the License.
;    You may obtain a copy of the License at
; 
;      http://www.apache.org/licenses/LICENSE-2.0
; 
;    Unless required by applicable law or agreed to in writing, software
;    distributed under the License is distributed on an "AS IS" BASIS,
;    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;    See the License for the specific language governing permissions and
;    limitations under the License.
; 

;; http://www.masteringemacs.org/articles/2013/07/31/comint-writing-command-interpreter/

(defvar metamap-cli-file-path "/mnt/public_mm/bin/metamap12"
  "Path to the program used by `run-metamap'")

(defvar metamap-cli-arguments '("--XMLf")
  "Commandline arguments to pass to `metamap-cli'")

(defvar metamap-mode-map
  (let ((map (nconc (make-sparse-keymap) comint-mode-map)))
    ;; example definition
    (define-key map (kbd "<tab>") 'metamap/toggle-element)
    (define-key map (kbd "C-c d") 'metamap/popup-doc-for-keyword)
    map)
  "Basic mode map for `run-metamap'")

(defvar metamap-prompt-regexp "^\\(|:\\)"
  "Prompt for `run-metamap'.")

(defun metamap ()
  "Run an inferior instance of `cassandra-cli' inside Emacs."
  (interactive)
  (let* ((metamap-program metamap-cli-file-path)
         (buffer (comint-check-proc "Metamap")))
    ;; pop to the "*Metamap*" buffer if the process is dead, the
    ;; buffer is missing or it's got the wrong mode.
    (pop-to-buffer-same-window
     (if (or buffer (not (derived-mode-p 'metamap-mode))
             (comint-check-proc (current-buffer)))
         (get-buffer-create (or buffer "*Metamap*"))
       (current-buffer)))
    ;; create the comint process if there is no buffer.
    (unless buffer
      (apply 'make-comint-in-buffer "Metamap" buffer
             metamap-program nil metamap-cli-arguments)
      (metamap-mode))))


(defun metamap--initialize ()
  "Helper function to initialize Cassandra"
  (setq comint-process-echoes t)
  (setq comint-use-prompt-regexp t))

(defun metamap/double-newline (input)
  (let ((string input))
    (while (s-ends-with? "\n" string)
      (setq string (s-chomp string)))
    (concat string "\n\n")))

(define-derived-mode metamap-mode comint-mode "Metamap"
  "Major mode for `run-metamap'.

\\<metamap-mode-map>"
  nil "Metamap"
  ;; this sets up the prompt so it matches things like: |:
  (setq comint-prompt-regexp metamap-prompt-regexp)
  ;; this makes it read only; a contentious subject as some prefer the
  ;; buffer to be overwritable.
  (setq comint-prompt-read-only t)
  ;; this makes it so commands like M-{ and M-} work.
  (set (make-local-variable 'paragraph-separate) "^\n")
;  (set (make-local-variable 'font-lock-defaults) '(metamap-font-lock-keywords t))
  (set (make-local-variable 'paragraph-start) metamap-prompt-regexp)

  ; (add-to-list 'comint-input-filter-functions 'metamap/double-newline)
  
  )

;; this has to be done in a hook. grumble grumble.
(add-hook 'metamap-mode-hook 'metamap--initialize)

(defvar metamap/tag-to-keyword-re "^ +</*\\([^ >]*\\)[ >]"
  "Regex to parse out a keyword from a tag")

(defvar metamap/doc-buffer-name "*Metamap Documentation*")

(defvar metamap/doc-format "
Tag: %s
Type: %s
Documentation:
%s

Press 'q' to quit.
")

(defun metamap/get-all-keywords ()
  (apply #'append (mapcar 'car metamap-keyword-documentation)))

(defun metamap/keyworkdp (kwd)
  (memberq kwd (metamap/get-all-keywords)))

(defun metamap/get-doc-entry (kwd)
  (car (delq nil (mapcar (lambda (entry) (and (member kwd (car entry)) entry)) metamap-keyword-documentation))))


(defun metamap/popup-doc-for-keyword ()
  (interactive)

  (re-search-forward metamap/tag-to-keyword-re)

  (let ((str (match-string 1))
	(cur-window-conf (current-window-configuration))
	(tmpbuf (get-buffer-create metamap/doc-buffer-name)))
    
    (display-buffer tmpbuf)
    (pop-to-buffer tmpbuf)
    (setq buffer-read-only nil)
    (erase-buffer)
    
    (insert (apply #'format (append (list metamap/doc-format) (cdr (metamap/get-doc-entry str)))))
    (setq buffer-read-only t)
    
    (set (make-local-variable 'metamap-return-window-config) cur-window-conf)
    (local-set-key (kbd "q") 
		   (lambda ()
		     (interactive) 
		     (set-window-configuration metamap-return-window-config)))
))

 
  
 
      

(defvar metamap-keyword-documentation
  '((("AAs" "AA") 
     "<AAs Count=\"N\"><AA>"
      "CR"
      " All the data generated for an author-defined Acronym/Abbreviation (AA),
consisting of

-   <AAText>: the text of the AA,
-   <AAExp>: its expansion,
-   <AATokenNum>: the number of tokens in the AA
-   <AALen>: the character length of the AA
-   <AAExpTokenNum>: the number of tokens in expansion
-   <AAExpLen>: the character length of its expansion, and
-   <AACUI>: any CUIs associated with the expansion of the AA

The following AA examples will use the text  
 polymerase chain reaction (PCR).
" )
    (("AACUIs" "AACUI") 
     "<AACUIs Count=\"N\"><AACUI>"
      "SR"
      "Any CUIs associated with the expansion of the AA.
" )
    (("AAExp") 
     "<AAExp>"
      "SU"
      "The expansion of the AA (polymerase chain reaction)
" )
    (("AAExpLen") 
     "<AAExpLen>"
      "SU"
      "The character length of the expansion of the AA (25, because polymerase
chain reaction contains 25 characters)
" )
    (("AAExpTokenNum") 
     "<AAExpTokenNum>"
      "SU"
      "The number of tokens in the AA expansion (5, because polymerase chain
reaction contains 5 tokens, including two blank tokens)
" )
    (("AALen") 
     "<AALen>"
      "SU"
      "The character length of the AA (3, because PCR contains 3 characters)
" )
    (("AAText") 
     "<AAText>"
      "SU"
      "The AA itself (PCR)
" )
    (("AATokenNum") 
     "<AATokenNum>"
      "SU"
      "The number of tokens in the AA (1, because PCR contains 1 token)
" )
    (("Candidates" "Candidate") 
     "<Candidates Total=\"T\" Excluded=\"E\" Pruned=\"P\" Remaining=\"R\"><Candidate>"
      "CR"
      "All the data generated for a candidate concept, including

-   <CandidateScore>: the candidate's negative score,
-   <CandidateCUI>: its CUI,
-   <CandidateMatched>: the candidate matched,
-   <CandidatePreferred>: its preferred name,
-   <MatchedWords>: the text word(s) it matches,
-   <MatchMaps>: the matchmap(s),
-   <SemTypes>: the semantic type(s),
-   <IsHead>: IsHead (yes/no),
-   <IsOverMatch>: IsOverMatch (yes/no),
-   <Sources>: the UMLS source(s),
-   <ConceptPIs>: the positional information, and
-   <Status>: 0/1/2 depending on if candidate is
    retained/excluded/pruned
")
    (("CandidateCUI") 
     "<CandidateCUI>"
      "SU"
      "The CUI of the candidate concept
" )
    (("CandidateMatched") 
     "<CandidateMatched>"
      "SU"
      "The candidate concept matched
" )
    (("CandidatePreferred") 
     "<CandidatePreferred>"
      "SU"
      "The preferred name of the candidate concept
" )
    (("CandidateScore") 
     "<CandidateScore>"
      "SU"
      "The negative score of the candidate concept; the computation of this
value is explained on pp. 5-9 of MetaMap Evaluation.
" )
    (("CmdLine") 
     "<CmdLine>"
      "CU"
      "All the data about the command used to start MetaMap, consisting of
-   <Command>: the actual operating-system call used to start MetaMap,
    and
-   <Option>: any options passed to MetaMap
" )
    (("Command") 
     "<Command>"
      "SU"
      "The actual operating-system call used to start MetaMap
" )
    (("ConceptPIs" "ConceptPI")
     "<ConceptPIs Count=\"N\"><ConceptPI>"
      "CR"
      "The positional information of the concept, consisting of

-   <StartPos>: the 0-based character offset of the concept, counting
    from the beginning of the input text, and
-   <Length>: the character length of the string
")
    (("ConcMatchEnd") 
     "<ConcMatchEnd>"
      "SU"
      "The position within the concept words of the last matching word
" )
    (("ConcMatchStart") 
     "<ConcMatchStart>"
      "SU"
      "The position within the concept words of the first matching word
" )
    (("InputMatch") 
     "<InputMatch>"
      "SU"
      "The input word(s) making up the syntax unit
" )
    (("IsHead") 
     "<IsHead>"
      "SU"
      "Yes/no value denoting if the candidate concept includes the head of the
phrase containing it
" )
    (("IsOverMatch") 
     "<IsOverMatch>"
      "SU"
      "Yes/no value denoting if the candidate concept is an overmatch, i.e., if
it contains words on one or both ends that do not match the input text.
" )
    (("Length") 
     "<Length>"
      "SU"
      "The character length of the string
" )
    (("LexCat") 
     "<LexCat>"
      "SU"
      "The lexical category of the syntax unit
" )
    (("LexMatch") 
     "<LexMatch>"
      "SU"
      "The lexical item(s) matched by the syntax unit
" )
    (("LexVariation") 
     "<LexVariation>"
      "SU"
      "The degree of lexical variation between the words in the candidate
concept and the words in the phrase; the computation of this value is
explained on pp. 2-3 of MetaMap Evaluation.
" )
    (("MappingCandidates") 
     "<MappingCandidates Total=\"N\"><Candidate>"
      "CU"
      "The candidate concepts participating in a mapping
" )
    (("Mappings" "Mapping") 
     "<Mappings Count=\"N\"><Mapping>"
      "CR"
      "A set of candidate concepts making up the mapping for the phrase,
consisting of

-   <MappingScore>: the negative score of the mapping, and
-   <MappingCandidates>: the candidate concept(s) participating in the
    mapping.
")
    (("MappingScore") 
     "<MappingScore>"
      "SU"
      "The negative score of the mapping; the computation of this value is
explained on pp. 9-10 of MetaMap Evaluation.
" )
    (("MatchedWords" "MatchedWord") 
     "<MatchedWords Count=\"N\"><MatchedWord>"
      "SR"
      "The word(s) in the input text matched by the candidate
" )
    (("MatchMaps" "MatchMap") 
     "<MatchMaps Count=\"N\"><MatchMap>"
      "CR"
      "
A data structure representing

-   the correspondence of words in the candidate concept
    (<TextMatchStart> and <TextMatchEnd>) and words in the phrase
    (<ConcMatchStart> and <ConcMatchEnd>), and
-   the lexical variation (<LexVariation>) between the words in the
    candidate concept and the words in the phrase.

For example, given the input text obstructive sleep apnea and the
candidate concept sleep apnea, the matching words sleep and apnea are

-   the 2nd and 3rd words of the text, and
-   the 1st and 2nd words of the concept.

There is no lexical variation, so the matchmap would therefore be
[[[2,3],[1,2],0]]. For the candidate concept sleep apneas, the MatchMap
would be the same, other than having lexical variation of 1 instead of
0.
")
(("MMOs" "MMO") 
 "<MMOs><MMO>"
  "CR"
  "All the XML output generated for an entire input record or citation,
consisting of

-   <CmdLine>: the command used to start MetaMap,
-   <AA>: any acronyms/abbreviation(s) found in the text,
-   <Negation>: any negation(s) found in the text, and
-   <Utterances>: the utterance(s) found in the text
")
(("Negations" "Negation") 
 "<Negations Count=\"N\"><Negation>"
 "CR"
 "All the data generated for a negation, including

-   <NegType>: the negation type,
-   <NegTrigger>: the negation trigger,
-   <NegTriggerPI>: the negation trigger's positional information,
-   <NegConcepts>: the negated concept(s), and
-   <NegConcPIs>: the negated concept's StartPos/Length positional
    information

For more information about MetaMap's implementation of NegEx, see the
MetaMap09 Release Notes.
")
(("NegConcCUI") 
 "<NegConcCUI>"
  "SU"
  "The CUI associated with the negated concept
" )
(("NegConcepts" "NegConcept")
 "<NegConcepts Count=\"N\"><NegConcept>"
  "CR"
  "The negated concept(s), consisting of

-   <NegConcCUI>: the negated concept's CUI, and
-   <NegConcMatched>: the negated concept's name
")
(("NegConcMatched") 
 "<NegConcMatched>"
  "SU"
  "The name of the negated concept
" )
(("NegConcPIs" "NegConcPI") 
 "<NegConcPIs Count=\"N\"><NegConcPI>"
  "CR"
  "The StartPos/Length positional information of the negated concept
" )
(("NegTrigger") 
 "<NegTrigger>"
  "SU"
  "The negation trigger
" )
(("NegTriggerPIs" "NegTriggerPI") 
 "<NegTriggerPIs Count=\"N\"><NegTriggerPI>"
  "CR"
  "The StartPos/Length positional information of the negation trigger
" )
(("NegType") 
 "<NegType>"
  "SU"
  "The negation type
" )
(("Options" "Option") 
 "<Options Count=\"N\"><Option>"
  "CR"
  "The option(s) passed to MetaMap, consisting of

-   <OptName>: the option's name, and
-   <OptValue>: the option's value.
")
(("OptName") 
 "<OptName>"
  "SU"
  "The name of the command-line option
" )
(("OptValue") 
 "<OptValue>"
  "SU"
  "The value of the command-line option (can be null)
" )
(("Phrases" "Phrase") 
 "<Phrases Count=\"N\"><Phrase>"
  "CR"
  "The syntactic subcomponent of the utterance, consisting of

-   <PhraseText>: the text of the phrase,
-   <SyntaxUnits>: the syntax unit(s),
-   <PhraseStartPos>: the 0-based character offset of the phrase,
    counting from the beginning of the input text
-   <PhraseLength>: the character length of the phrase,
-   <Candidate>: any candidate concepts identified in the phrase, and
-   <Mapping>: any mappings created
")
(("PhraseLength") 
 "<PhraseLength>"
  "SU"
  "The character length of the phrase
" )
(("PhraseStartPos") 
 "<PhraseStartPos>"
  "SU"
  "The 0-based character offset of the phrase, counting from the beginning
of the input text
" )
(("PhraseText") 
 "<PhraseText>"
  "SU"
  "The text of the phrase
" )
(("PMID") 
 "<PMID>"
  "SU"
  "The PubMed ID of the citation containing the utterance
" )
(("SemTypes" "SemType") 
 "<SemTypes Count=\"N\"><SemType>"
  "SR"
  "The semantic type(s) of the candidate
" )
(("Sources" "Source") 
 "<Sources Count=\"N\"><Source>"
  "SR"
  "The UMLS vocabulary/ies in which the concept was found
" )
(("StartPos") 
 "<StartPos>"
  "SU"
  "The 0-based character offset of the string, counting from the beginning
of the input text
" )
(("Status") 
 "<Status>"
  "SU"
  "0, 1, or 2, representing if candidate was retained (0), excluded (1), or
pruned (2)
" )
(("SyntaxType") 
 "<SyntaxType>"
  "SU"
  "The syntactic type of the syntax unit (e.g., head, mod, verb, etc.)
" )
(("SyntaxUnits" "SyntaxUnit") 
 "<SyntaxUnits Count=\"N\"><SyntaxUnit>"
  "CR"
  "The syntactic subcomponent of the phrase, consisting of

-   <SyntaxType>: the syntactic type of the syntax unit (e.g., head,
    mod, verb, etc.,
-   <LexMatch>: the lexical item(s),
-   <InputMatch>: the input word(s),
-   <LexCat>: the lexical category, and
-   <Tokens>: the token(s) making up the lexical items
")
(("TextMatchEnd") 
 "<TextMatchEnd>"
  "SU"
  "The position within the phrase words of the last matching word
" )
(("TextMatchStart") 
 "<TextMatchStart>"
  "SU"
  "The position within the phrase words of the first matching word
" )
(("Tokens" "Token") 
 "<Tokens Count=\"N\"><Token>"
  "SR"
  "The tokens making up the lexical items
")
(("Utterances" "Utterance") 
 "<Utterances Count=\"N\"><Utterance>"
  "CR"
  "All the data generated for an utterance, including

-   <PMID>: the utterance's PubMed ID,
-   <UttSection>: the section type (e.g., title or abstract),
-   <UttNum>: the 1-based utterance number within the section,
-   <UttText>: the text of the utterance,
-   <UttStartPos>: the 0-based character offset of the utterance,
    counting from the beginning of the input text
-   <UttLength>: the length, and
-   <Phrases>: the phrase(s) making up the utterance
")
(("UttLength") 
 "<UttLength>"
  "SU"
  "The character length of the utterance
")
(("UttNum") 
 "<UttNum>"
  "SU"
  "The 1-based numerical position of the utterance within the section
")
(("UttSection") 
 "<UttSection>"
  "SU"
  "The section type (e.g., title or abstract) of the utterance
")
(("UttStartPos") 
 "<UttStartPos>"
  "SU"
  "The 0-based character offset of the utterance, counting from the
beginning of the input text
")
(("UttText") 
 "<UttText>"
  "SU"
  "The text of the utterance
"))
"Documentation strings for keywords related to metamap XML output
 Each entry is of the form ((keyword1 keyword2 ... ) tag type definition)...
 Several entries take multiple keywords such as Utterances and Utterance.")

(add-hook 'metamap-mode-hook
	  (lambda ()
	    (font-lock-add-keywords nil
				    '((">\\(.*\\)<" 
				       (1 font-lock-keyword-face))))
	    ))

(defun metamap/toggle-element ()
  (interactive)
  (save-excursion 
    (let* ((end (progn (sgml-skip-tag-forward 1) (point)))
	   (start (progn (sgml-skip-tag-backward 1) (point)))
	   (eol (progn (move-end-of-line 1) (point)))
	   (ol-list (overlays-in start eol)))
      (if (> (length ol-list) 0)
	  ; if there is an overlay,  remove it
	  (delete-overlay (car ol-list))
	;if no overlay, add it
	(let ((ol (make-overlay start end (current-buffer) t nil))
	      (before-text (concat (buffer-substring-no-properties start eol) "..." )))       
	  (overlay-put ol 'invisible t)
	  (overlay-put ol 'before-string before-text))))))

(provide 'metamap-mode)
