
all: rel

get-deps: priv/cuttlefish priv/erlang_vm.schema
	./rebar get-deps

cuttlefish.tar.gz:
	wget https://github.com/basho/cuttlefish/archive/2.0.6.tar.gz --output-document=$@

cuttlefish: cuttlefish.tar.gz
	tar xzf $<
	mv cuttlefish-2.0.6 $@

cuttlefish/cuttlefish: cuttlefish
	cd $<; make; cd ..

priv/erlang_vm.schema: cuttlefish
	mkdir -p priv
	cp cuttlefish/priv/erlang_vm.schema $@

priv/cuttlefish: cuttlefish/cuttlefish
	mkdir -p priv
	cp $< $@

compile:
	./rebar compile

clean:
	./rebar skip_deps=true clean

console:
	rel/$(PROJECT_REPO)/bin/$(PROJECT) console

test:
	./rebar skip_deps=true eunit

xref:
	./rebar skip_deps=true xref

define REWRITE_RELEASES_ESCRIPT
'[ReleaseDir] =\
	[D || D <- string:tokens(os:cmd("ls -1 releases/"), "\n"),\
		D =/= "RELEASES",\
		D =/= "start_erl.data"],\
RelFile = "releases/" ++ ReleaseDir ++ "/$(PROJECT).rel",\
ok = release_handler:create_RELEASES(".", "releases", RelFile, []).'
endef

define REWRITE_RELEASES
	cd rel/$(PROJECT_REPO) && erl -eval $(REWRITE_RELEASES_ESCRIPT) -s init stop -noshell && cd -
endef

define CREATE_START_BOOT_FILE
TAG=$$(git describe); \
cp "rel/$(PROJECT_REPO)/releases/$$TAG/$(PROJECT).boot" "rel/$(PROJECT_REPO)/releases/$$TAG/start.boot"
endef

export REWRITE_RELEASES_ESCRIPT
print:
	echo "$$REWRITE_RELEASES_ESCRIPT"

generate-rel:
	./rebar generate
	$(REWRITE_RELEASES)
	$(CREATE_START_BOOT_FILE)
ifneq (,$(wildcard rel/files/app.config))
	cp rel/files/app.config rel/$(PROJECT_REPO)/etc
endif
ifneq (,$(wildcard rel/files/app.config.placeholder))
	cp rel/files/app.config.placeholder rel/$(PROJECT_REPO)/etc
endif

rel: get-deps compile xref relclean test generate-rel

relclean:
	rm -rf rel/$(PROJECT_REPO)

.PHONY: all get-deps compile clean console test xref print rel relclean

## DIALYZER

OTP_PLT=~/.otp.plt
PRJ_PLT=local.plt

SOLVER = --solver v2

dialyzer_diff:
	wget -O $@ https://raw.githubusercontent.com/AntonSizov/erl.mk/master/$@
	chmod +x $@

.PHONY: dialyzer_warnings
dialyzer_warnings:
	$(info Dialyze project...)
# add '|| true' to ignore dialyzer return code
	@(dialyzer $(SOLVER) -Wno_return -Wno_unused --plt $(PRJ_PLT) \
	-r ebin -q > dialyzer_warnings || true)

.dialyzerignore:
	touch $@

dialyze: .dialyzerignore dialyzer_warnings dialyzer_diff $(OTP_PLT) $(PRJ_PLT)
	$(info Output found warnings)
	@./dialyzer_diff dialyzer_warnings .dialyzerignore

rm-project-plt:
	$(info Cleanup project plt)
	rm -f $(PRJ_PLT)

APPS = erts \
	kernel stdlib crypto mnesia sasl ssl eunit \
	compiler tools syntax_tools asn1 public_key

$(OTP_PLT):
	$(info Build OTP PLT...)
	dialyzer $(SOLVER) --build_plt --output_plt $@ --apps $(APPS)

$(PRJ_PLT):
# || true - to ignore dialyzer build plt warnings
	$(info Build local PLT...)
	@(dialyzer $(SOLVER) --add_to_plt --plt $(OTP_PLT) --output_plt $(PRJ_PLT) \
	-r ./deps/*/ebin ebin || true)
