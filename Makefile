.PHONY: clean

NAME=virtio-gpu.pdf

FILES=src/virtio-gpu.md
COVER=src/cover.yaml

EXTS=+footnotes+implicit_figures+backtick_code_blocks

$(NAME): $(FILES) templates/template.tex cover.tex
	pandoc                                  \
	  --from         markdown$(EXTS)        \
	  --to           latex                  \
	  --template     templates/template.tex \
	  --out          $@                     \
	  --latex-engine xelatex                \
	  --css templates/pandoc.css            \
	  $(FILES)

cover.tex: templates/cover.j2 $(COVER)
	cp $< $@
	@echo generating $@ from $< and $(COVER)

clean:
	rm -f $(NAME)
	rm -f cover.tex
