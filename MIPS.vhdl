library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity nips is
	port (
		clk, reset: in std_logic;
		OutA, OutB: inout std_logic_vector(31 downto 0);
		input: inout std_logic_vector(31 downto 0);
		writeEnable: inout std_logic;
		regAsel, regBsel, writeRegSel: inout std_logic_vector(4 downto 0);
		cycleButton: in std_logic;
		db_level, db_tick: inout std_logic;
		switches: in std_logic_vector(7 downto 0);
		q: out std_logic_vector(7 downto 0);
	);
end mips;

architecture fsmd_arch of mips is
	type reg_state_type is (s0, s1, s2, s3, s4, s5, s6, s7, s8, s9);
	signal state_reg, state_next: reg_state_type:=s0;
	signal regA, regB, regC: unsigned(31 downto 0);
	signal pc: unsigned(15 downto 0);
	
	signal ir: std_logic_vector(31 downto 0);

begin

process(clk, reset)
begin
	if (reset='1') then
		state_reg <= s0;
	elsif (clk'event and clk='1') then
		state_reg <= state_next;
	end if;
end process;

process (state_reg, db_tick)
begin
    case state_reg is
        when s0 =>
            ir(31 downto 24) <= switches;
            --q <= "11111111";
            
            if (db_tick = '1') then
                state_next <= s1;
            else
                state_next <= state_reg;
            end if;
        when s1 =>
            ir(23 downto 16) <= switches;
            --q <= "00000001";
            
            if (db_tick = '1') then
                state_next <= s2;
            else
                state_next <= state_reg;
            end if;
        when s2 =>
            ir(15 downto 8) <= switches;
            --q <= "00000011";
            
            if (db_tick = '1') then
                state_next <= s3;
            else
                state_next <= state_reg;
            end if;
        when s3 =>
            ir(7 downto 0) <= switches;
            --q <= "00000111";
            
            if (db_tick = '0') then
                state_next <= state_reg;
            else
                --Check op codes and function
                if (ir(31 downto 26) = "000000") then
                    if (ir(5 downto 0) = "100000") then
                        state_next <= s4;
                    elsif (ir(5 downto 0) = "100010") then
                        state_next <= s5;
                    elsif (ir(5 downto 0) = "100100") then
                        state_next <= s6;
                    elsif (ir(5 downto 0) = "100101") then
                        state_next <= s7;
                    else
                        state_next <= s0;
                    end if;
                elsif (ir(31 downto 26) = "000100") then
                    state_next <= s8;
                else
                    state_next <= s0;
                end  if;
            end if;
        when s4 => 
            regAsel <= ir(25 downto 21);
            regBsel <= ir(20 downto 16);
            writeRegSel <= ir(15 downto 11);
            writeEnable <= '1';
            
            --regA <= unsigned(OutA);
            --regB <= unsigned(OutB);
            regC <= regA+regB;
            
            input <= std_logic_vector(regC);
            
            --q <= std_logic_vector(regC(7 downto 0));
            
            if (db_tick = '1') then
                state_next <= s9;
            else
                state_next <= state_reg;
            end if;
        when s5 =>
            regAsel <= ir(25 downto 21);
            regBsel <= ir(20 downto 16);
            writeRegSel <= ir(15 downto 11);
            writeEnable <= '1';
            
            --regA <= unsigned(OutA);
            --regB <= unsigned(OutB);
            regC <= regA-regB;
            
            input <= std_logic_vector(regC);
            
            --q <= std_logic_vector(regC(7 downto 0));
            
            if (db_tick = '1') then
                state_next <= s9;
            else
                state_next <= state_reg;
            end if;
        when s6 =>
            --And things together
            regAsel <= ir(25 downto 21);
            regBsel <= ir(20 downto 16);
            writeRegSel <= ir(15 downto 11);
            writeEnable <= '1';
            input <= (std_logic_vector(RegA) and std_logic_vector(RegB));
            
            if (db_tick = '1') then
                state_next <= s9;
            else
                state_next <= state_reg;
            end if;
        when s7 =>
            --Or things together
            regAsel <= ir(25 downto 21);
            regBsel <= ir(20 downto 16);
            writeRegSel <= ir(15 downto 11);
            writeEnable <= '1';
            --input <= (std_logic_vector(RegA) or std_logic_vector(RegB));
            
            if (db_tick = '1') then
                state_next <= s9;
            else
                state_next <= state_reg;
            end if;
        when s8 =>
            --Branch if equal
            --regAsel <= ir(25 downto 21);
            --regBsel <= ir(20 downto 16);
            
--            if (OutA = OutB) then
--                pc <= unsigned(ir(15 downto 0));
--            end if;
            
            if (db_tick = '1') then
                state_next <= s9;
            else
                state_next <= state_reg;
            end if;
        when s9 =>
            --Output state
            regAsel <= switches(4 downto 0);
            writeEnable <= '0';
            
            --Increment the program counter
            pc <= pc+1;
            
            --q <= OutA(7 downto 0);
            
            if (db_tick = '1') then
                state_next <= s0;
            else
                state_next <= state_reg;
            end if;
    
    end case;
end process;

process(state_reg)
begin
    if (state_reg = s4 or state_reg = s5 or state_reg = s6 or state_reg = s7) then
        regA <= unsigned(OutA);
        regB <= unsigned(OutB);
        q <= std_logic_vector(RegC(7 downto 0));
    elsif (state_reg = s9) then
        q <= OutA(7 downto 0);
    elsif (state_reg = s0) then
        q <= "00000000";
    elsif (state_reg = s1) then
        q <= "00000001";
    elsif (state_reg = s2) then
        q <= "00000011";
    end if;
end process;

register_unit: entity register_file
port map(
    clk=>clk,
    OutA=>OutA, OutB=>OutB,
    input=>input,
    writeEnable=>writeEnable,
    regAsel=>regAsel, regBsel=>regBsel,
    writeRegSel=>writeRegSel);
    
debounce_unit: entity debounce
port map(
    clk=>clk, reset=>reset,
    sw=>cycleButton,
    db_level=>db_level,
    db_tick=>db_tick);
    
end fsmd_arch;
