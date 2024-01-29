SERVER_PORT=8080
RUN_FLASK=flask --app Mock/app.py run

.PHONY: server_environment
server_environment:
	python3 -m pip install -r Mock/requirements.txt

.PHONY: setup_server
setup_server: server_environment
	$(RUN_FLASK) --port $(SERVER_PORT) &

.PHONY: teardown_server
teardown_server:
	kill -9 $$(lsof -t -i :$(SERVER_PORT))


######### Production #########
.PHONY: release
release: test
	swift build --release

.PHONY: test
test:
	make unit_test
	make integration_test

.PHONY: unit_test
unit_test:
	swift test --skip IntegrationTests

.PHONY: integration_test
integration_test:
	make setup_server
	sleep 5
	curl http://localhost:8080
	swift test -Xswiftc -DINTEGRATION_TEST --filter IntegrationTests
	make teardown_server


.PHONY: package
package:
	echo "make package is not implemented"

######### Testing #########
.PHONY: debug_build
debug_build:
	swift build
	
.PHONY: debug_unit_test
debug_unit_test:
	swift test -Xswiftc -DDEBUG --skip IntegrationTests 

.PHONY: debug_integration_test
debug_integration_test:
	make setup_server
	swift test -Xswiftc -DINTEGRATION_TEST -Xswiftc -DDEBUG --filter IntegrationTests
	make teardown_server
	

.PHONY: clean
clean:
	rm -rf .build .swiftpm Package.resolved || true