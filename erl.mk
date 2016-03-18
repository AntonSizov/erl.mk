
all: rel

get-deps:
	./rebar get-deps || true
ifneq ($(findstring just,$(shell git remote -v)),)
	rm -rf deps/lager deps/goldrush
	grep -v '//github.com/basho/lager.git' deps/cuttlefish/rebar.config > deps/cuttlefish/rebar.config.new
	mv deps/cuttlefish/rebar.config.new deps/cuttlefish/rebar.config
	./rebar get-deps
endif

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

rel: get-deps compile xref relclean test generate-rel

relclean:
	rm -rf rel/$(PROJECT_REPO)

.PHONY: all get-deps compile clean console test xref print rel relclean
