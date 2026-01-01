.PHONY: up down destroy rebuild 

rebuild: destroy up

destroy:
	vagrant destroy -f 

down:
	vagrant halt 

up: 
	vagrant up


ssh-%:
	vagrant ssh $*
