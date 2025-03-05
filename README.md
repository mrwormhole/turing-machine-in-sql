# turing-machine-in-sql

Implemented turing machine simulation in SQL to prove that "SQL is indeed a programming language"

![palindrome-state-diagram](./palindrome-state-diagram.png)

```mermaid
stateDiagram-v2
    [*] --> q0
    
    q0 --> q1: 0 / _, R
    q0 --> q2: 1 / _, R
    q0 --> yes: _ / _, N
    
    q1 --> q1: 0 / 0, R
    q1 --> q1: 1 / 1, R
    q1 --> q3: _ / _, L
    
    q2 --> q2: 0 / 0, R
    q2 --> q2: 1 / 1, R
    q2 --> q4: _ / _, L
    
    q3 --> q5: 0 / _, L
    q3 --> no: 1 / 1, N
    q3 --> yes: _ / _, N
    
    q4 --> q5: 1 / _, L
    q4 --> no: 0 / 0, N
    q4 --> yes: _ / _, N
    
    q5 --> q5: 0 / 0, L
    q5 --> q5: 1 / 1, L
    q5 --> q0: _ / _, R
    
    yes --> [*]: Accepted
    no --> [*]: Rejected
```

### Getting started

```shell
  $ git clone https://github.com/mrwormhole/turing-machine-in-sql
  $ docker compose up -d --build
  $ docker exec -it postgres-turing psql -U turing -d turing_machine
  turing_machine=# select * FROM machine_steps;
  turing_machine=# call run_palindrome_program('1001');
  turing_machine=# select * FROM machine_steps;
```

The original blog post can be found [here](https://wormholerelays.com/posts/sql-turing-completeness)
