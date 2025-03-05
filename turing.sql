-- machine for Turing machine
CREATE TABLE machine (
    initial_state VARCHAR(64) NOT NULL,
    accept_state VARCHAR(64) NOT NULL,
    reject_state VARCHAR(64) NOT NULL,
    blank_symbol VARCHAR(1) NOT NULL DEFAULT '_',
    max_steps INTEGER NOT NULL DEFAULT 1000
);

-- transition_rules for Turing machine
CREATE TABLE transition_rules (
    state VARCHAR(64) NOT NULL,
    new_state VARCHAR(64) NOT NULL,
    read_symbol VARCHAR(1) NOT NULL,
    write_symbol VARCHAR(1) NOT NULL,
    move_direction VARCHAR(1) NOT NULL CHECK (move_direction IN ('L', 'R', 'N'))
);

-- machine_steps to store execution steps of Turing machine
CREATE TABLE machine_steps (
    step INTEGER NOT NULL,
    state VARCHAR(64) NOT NULL,
    tape TEXT NOT NULL,
    position INTEGER NOT NULL,
    halted BOOLEAN NOT NULL DEFAULT FALSE
);

-- initialize_machine initializes the Turing machine for a specific program
CREATE OR REPLACE PROCEDURE initialize_machine(
    initial_state VARCHAR(64),
    accept_state VARCHAR(64),
    reject_state VARCHAR(64),
    blank_symbol VARCHAR(1) DEFAULT '_',
    max_steps INTEGER DEFAULT 1000
) AS $$
BEGIN
    DELETE FROM machine; -- clear
    
    INSERT INTO machine VALUES (initial_state, accept_state, reject_state, blank_symbol, max_steps);
END;
$$ LANGUAGE plpgsql;

-- add_transition_rule adds transition rule for a specific program
CREATE OR REPLACE PROCEDURE add_transition_rule(
    state VARCHAR(64),
    new_state VARCHAR(64),
    read_symbol VARCHAR(1),
    write_symbol VARCHAR(1),
    move_direction VARCHAR(1)
) AS $$
BEGIN
    INSERT INTO transition_rules VALUES (state, new_state, read_symbol, write_symbol, move_direction);
END;
$$ LANGUAGE plpgsql;

-- run_step executes a single step of machine
CREATE OR REPLACE FUNCTION run_step(
    current_state VARCHAR(64),
    accept_state VARCHAR(64),
    reject_state VARCHAR(64),
    tape TEXT,
    pos INTEGER,
    blank VARCHAR(1)
) RETURNS TABLE (
    new_state VARCHAR(64),
    new_tape TEXT,
    new_pos INTEGER,
    halted BOOLEAN
) AS $$
DECLARE
    tape_length INTEGER;
    symbol VARCHAR(1);
    rule RECORD;
BEGIN
    -- check if it is a final state
    IF current_state = accept_state OR current_state = reject_state THEN
        RETURN QUERY SELECT current_state, tape, pos, TRUE;
        RETURN;
    END IF;

    tape_length := length(tape);

    -- get the current symbol
    IF pos < 1 OR pos > tape_length THEN
        symbol := blank;
    ELSE
        symbol := substr(tape, pos, 1);
    END IF;
    
    -- query transition rule
    SELECT * INTO rule FROM transition_rules tr
    WHERE tr.state = current_state AND tr.read_symbol = symbol
    LIMIT 1;
    
    IF rule IS NULL THEN -- no rule found, halt
        RETURN QUERY SELECT current_state, tape, pos, TRUE;
        RETURN;
    END IF;
 
    IF pos < 1 THEN -- extend tape left
        tape := rule.write_symbol || tape;
        pos := 1;
    ELSIF pos > tape_length THEN -- extend tape right
        tape := tape || rule.write_symbol;
    ELSE
        tape := substr(tape, 1, pos-1) || rule.write_symbol || substr(tape, pos+1);
    END IF;
    
    IF rule.move_direction = 'L' THEN
        pos := pos - 1;
    ELSIF rule.move_direction = 'R' THEN
        pos := pos + 1;
    END IF;
    
    RETURN QUERY SELECT rule.new_state, tape, pos, FALSE;
END;
$$ LANGUAGE plpgsql;

-- run_machine runs machine
CREATE OR REPLACE PROCEDURE run_machine(t TEXT) AS $$
DECLARE
    tape TEXT := COALESCE(t, '');
    state VARCHAR(64);
    position INTEGER := 1;
    accept_state VARCHAR(64);
    reject_state VARCHAR(64);
    blank_symbol VARCHAR(1);
    max_steps INTEGER;
    halted BOOLEAN := FALSE;
    step INTEGER := 0;
BEGIN
    DELETE FROM machine_steps; -- clear
    
    -- read machine state
    SELECT m.initial_state, m.accept_state, m.reject_state, m.blank_symbol, m.max_steps
    INTO state, accept_state, reject_state, blank_symbol, max_steps
    FROM machine m;
    
    -- record machine step
    INSERT INTO machine_steps (step, state, tape, position, halted)
    VALUES (step, state, tape, position, halted);
    
    WHILE NOT halted AND step < max_steps LOOP
        step := step + 1;
        
        -- execute one machine step and directly assign results to main variables
        SELECT fn.new_state, fn.new_tape, fn.new_pos, fn.halted
        INTO state, tape, position, halted
        FROM run_step(state,  accept_state, reject_state, tape, position, blank_symbol) fn;
        
        -- record one machine step
        INSERT INTO machine_steps (step, state, tape, position, halted)
        VALUES (step, state, tape, position, halted);
    END LOOP;
    
    -- check if we timed out
    IF step = max_steps AND NOT halted THEN
        UPDATE machine_steps SET state = 'TIMEOUT', halted = TRUE
        WHERE step = max_steps;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- run_palindrome_program runs the palindrome program in Turing machine
CREATE OR REPLACE PROCEDURE run_palindrome_program(t TEXT) AS $$
BEGIN
    DELETE FROM transition_rules; -- clear
    
    CALL initialize_machine('q0', 'yes', 'no');
    
    -- q0: read left most symbol and move right side
    CALL add_transition_rule('q0', 'q1', '0', '_', 'R'); 
    CALL add_transition_rule('q0', 'q2', '1', '_', 'R'); 
    CALL add_transition_rule('q0', 'yes', '_', '_', 'N'); 
    
    -- q1: 0 was at the beginning, now go to the right-most end
    CALL add_transition_rule('q1', 'q1', '0', '0', 'R'); 
    CALL add_transition_rule('q1', 'q1', '1', '1', 'R'); 
    CALL add_transition_rule('q1', 'q3', '_', '_', 'L'); 
    
    -- q2: 1 was at the beginning, now go to the right-most end
    CALL add_transition_rule('q2', 'q2', '0', '0', 'R'); 
    CALL add_transition_rule('q2', 'q2', '1', '1', 'R'); 
    CALL add_transition_rule('q2', 'q4', '_', '_', 'L'); 
    
    -- q3: check if last symbol matches for 0 at the beginning
    CALL add_transition_rule('q3', 'q5', '0', '_', 'L'); 
    CALL add_transition_rule('q3', 'no', '1', '1', 'N'); 
    CALL add_transition_rule('q3', 'yes', '_', '_', 'N'); 
    
    -- q4: check if last symbol matches for 1 at the beginning
    CALL add_transition_rule('q4', 'q5', '1', '_', 'L'); 
    CALL add_transition_rule('q4', 'no', '0', '0', 'N'); 
    CALL add_transition_rule('q4', 'yes', '_', '_', 'N'); 
    
    -- q5: now go back to the left-most end
    CALL add_transition_rule('q5', 'q5', '0', '0', 'L'); 
    CALL add_transition_rule('q5', 'q5', '1', '1', 'L'); 
    CALL add_transition_rule('q5', 'q0', '_', '_', 'R'); 
    
    CALL run_machine(t);
END;
$$ LANGUAGE plpgsql;

