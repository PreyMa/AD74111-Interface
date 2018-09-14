----------------------------------------------------------------------------------
-- Company: 		 HTBL-Hollabrunn
-- Engineer: 		 Matthias Preymann 5BHEL 
-- 
-- Create Date:    08:43:34 09/12/2018 
-- Design Name: 
-- Module Name:    automat - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity automat is
	 generic( default_config : std_logic_vector( 15 downto 0 ) := "1001100000001111" );
    Port ( control_mode : in  STD_LOGIC;
           busy : out  STD_LOGIC;
           clock : in  STD_LOGIC;
           enable : in  STD_LOGIC;
           reset : in  STD_LOGIC;
			  set : in std_logic;
           pin : in  STD_LOGIC_VECTOR (23 downto 0);
           pout : out  STD_LOGIC_VECTOR (23 downto 0);
           codec_sync : in  STD_LOGIC;
           codec_din : in  STD_LOGIC;
           codec_dout : out  STD_LOGIC;
           codec_reset : out  STD_LOGIC);
end automat;

architecture Behavioral of automat is

type StateType is (ResetState, startMaster, getSync, getSyncReset, initControl, pauseInitControl, pauseSendControl, sendControl, 
						 syncInit, syncIgnore, syncSend, waitForSync, pauseSendData, sendData, saveData, stallInitControl );

-- Registers
signal curState : StateType;
signal nextState : StateType;											-- current state
signal dataMode : std_logic_vector( 1 downto 0 );				-- data width mode (16/20/24 bits)

signal counter : integer range 0 to 63;							-- intrnal counter for shifting and waiting

signal controlRegister : std_logic_vector( 15 downto 0 );	-- holding next control word to send, reset to zero after shifting
signal statusRegister : std_logic_vector( 15 downto 0 );		-- holding last received status word

signal dacRegister : std_logic_vector( 23 downto 0 );			-- holding next dac data to send, keeps its value until new one is set via parallel in (pin)
signal adcRegister : std_logic_vector( 23 downto 0 );			-- holding last received adc word

signal shiftInRegister : std_logic_vector( 23 downto 0 );	-- shift in register for receiving serial data
signal shiftOutRegister : std_logic_vector( 23 downto 0 );	-- shift out register for transmitting serial data

-- Signals
signal reg_guard : std_logic;			-- prevent loading new control or dac data from parallel in (pin)

signal ctr_inc : std_logic;			-- increment counter on positive edge
signal ctr_reset : std_logic;			-- synchronously set the counter to 0x00 on positive edge
signal negedge : std_logic;			-- allow state updates on negative clock edges

signal load_control : std_logic;		-- copy control register value to the shift out regsiter
signal load_dac : std_logic;			-- copy dac data register value to the shift out register
signal save_status : std_logic;		-- copy shifted in value to the status register
signal save_adc : std_logic;			-- copy shifted in value to the adc data register

signal shift_out : std_logic;			-- allow shifting out of data to codec_dout
signal shift_in : std_logic;			-- allow shifting in of data from codec_din
signal shift_msb : std_logic;			-- shift register bit nr. dataMode-1
signal shift_in_done : std_logic;	-- high when the output shift register has run dataMode-1 times

signal data_mode : std_logic_vector( 1 downto 0 );
signal shift_adc_value : std_logic_vector( 23 downto 0 );

signal testcntr : unsigned( 7 downto 0 );

begin

-- Asynchronous

testcntr <= to_unsigned( counter, 8 );	-- Internal debug signal, as Isim doesn't allow the Radix-option on integer signals

pout <= adcRegister when control_mode = '0' else ("00000000") & statusRegister;

data_mode <= pin( 5 downto 4 ) when pin( 14 downto 11 ) = "0010" else dataMode;

shift_msb <= 	shiftOutRegister( 15 ) when dataMode = "00" else
					shiftOutRegister( 19 ) when dataMode = "01" else 
					shiftOutRegister( 23 );
					
shift_adc_value <=	("00000000") & shiftInRegister( 15 downto 0 ) when dataMode = "00" else
							(    "0000") & shiftInRegister( 19 downto 0 ) when dataMode = "01" else
							shiftInRegister;
					
shift_in_done <=	'1' when dataMode = "00" and counter = 15 else
						'1' when dataMode = "01" and counter = 19 else
						'1' when dataMode = "10" and counter = 23 else
						'1' when dataMode = "11" and counter = 23 else
						'0';

-- Automat

SYNC : process( reset, clock )
begin 
	
	if( reset = '1' ) then
		curState <= ResetState;
		controlRegister <= default_config;
		statusRegister <= (others => '0');
		
		dacRegister <= (others => '0');
		adcRegister <= (others => '0');
		
		shiftOutRegister <= (others => '0');
		counter <= 0;
		dataMode <= "00";
		
	elsif( clock' event and enable = '1' ) then
		if( clock = '1' ) then 
			
			curState <= nextState;
			
			-- increment or reset the counter synchronously
			if( ctr_reset = '1' ) then
				counter <= 0;
			elsif( ctr_inc = '1' ) then 
				counter <= counter +1;
			end if;
			
			-- Shift data out from register
			if( shift_out = '1' ) then
				shiftOutRegister <= shiftOutRegister( 22 downto 0 ) & '0';
			end if;
			
			
--			-- Load the control or dac register to the shifter
			if( load_control= '1' ) then
				shiftOutRegister <= ("00000000") & controlRegister;
				controlRegister <= (others => '0' );
				
			elsif( load_dac = '1' ) then 
				shiftOutRegister <= dacRegister;
			end if;
			
			-- Save rcv-shift register to data registers
			if( save_status = '1' ) then
				statusRegister <= shiftInRegister( 15 downto 0 );
			elsif( save_adc = '1' ) then 
				adcRegister <= shift_adc_value;
			end if;
			
			-- Save new input data to the control or dac register
			if( set = '1' ) then
				if( control_mode = '1' ) then
					if( load_control = '0' and reg_guard = '0' ) then
					
						controlRegister <= pin( 15 downto 0 );
						dataMode <= data_mode;
					end if;
				else 
					dacRegister <= pin;
				end if;
			end if;
			
		else 
			
			-- only allow negative edge triggering in sync-states
			if( negedge = '1' ) then
				
				curState <= nextState;
				
				-- Shift data into register
				if( shift_in = '1' ) then
					shiftInRegister <= shiftInRegister( 22 downto 0 ) & codec_din;
				end if;
							
				
			end if;
			
		end if;
		
	end if;
end process SYNC;

----------------------------------------------------------------
----------------------------------------------------------------

ASYNC : process( curState, control_mode, pin, codec_sync, codec_din, set, counter, shift_msb )
begin
	-- defaut / common signal values
	nextState <= curState;
	
	reg_guard <= '0';
	busy <= '1';
	codec_reset <= '0';
	ctr_inc <= '0';
	ctr_reset <= '1';
	negedge <= '0';
	load_control <= '0';
	load_dac <= '0';
	shift_out <= '0';
	codec_dout <= '0';
	
	case curState is
		------------------- Reset -------------------
		when ResetState =>
			reg_guard <= '1';
			nextState <= StartMaster;
			
		---------------- StartMaster ----------------
		when StartMaster =>
			ctr_inc <= '1';
			ctr_reset <= '0';
			
			reg_guard <= '1';			
			codec_reset <= '1';
			
			if( counter = 10 ) then
				ctr_reset <= '1';
				
				nextState <= getSync;
			end if;
			
			
		------------------ getSync ------------------
		when getSync =>
			ctr_inc <= '1';			-- increment counter 
			ctr_reset <= '0';
			
			negedge <= '1';			-- allow double edge triggering
			reg_guard <= '1';
			
			if( counter = 63 ) then	-- run up to 63
				ctr_reset <= '1';		-- reset  counter
				
				nextState <= syncInit;
				
			end if;
			
			if( codec_sync = '1' ) then -- if a sync signal is found reset the counter
				ctr_reset <= '1';			 -- and stay in the state
				
				nextState <= getSyncReset;
			end if;
			
			
		--------------- getSyncReset -----------------
		when getSyncReset =>
			ctr_reset <= '1';
			reg_guard <= '1';
			
			nextState <= getSync;
			
			
		----------------- syncInit -----------------
		when syncInit =>
			negedge <= '1';
			reg_guard <= '1';
						
			if( codec_sync = '1' ) then
				nextState <= pauseInitControl;
			end if;
			
			
		------------- pauseInitControl -------------
		when pauseInitControl =>
			load_control <= '1';			-- load control register value to the shifter	
			reg_guard <= '1';			
			nextState <= stallInitControl;
			
		
		---------------- initControl ---------------
		when initControl =>
			ctr_inc <= '1';
			ctr_reset <= '0';
			
			shift_out <= '1';				-- shift out data
			codec_dout <= shiftOutRegister( 15 );
			
			nextState <= stallInitControl;
			
			if( counter = 15 ) then 	-- run 16 times
				ctr_reset <= '1';
				
				nextState <= syncIgnore;
			end if;
			
			
			
		------------- stallInitControl --------------
		when stallInitControl =>
			ctr_reset <= '0';
			
			codec_dout <= shiftOutRegister( 15 );
			nextState <= initControl;
			
			
		---------------- syncIgnore ------------------
		when syncIgnore =>
			negedge <= '1';
			
			if( codec_sync = '1' ) then
				nextState <= waitForSync;
			end if;
			
		
		--------------- waitForSync ----------------
		when waitForSync =>
			busy <= '0';
			negedge <= '1';
			
			if( codec_sync = '1' ) then				
				nextState <= pauseSendControl;
			end if;
			
			
		------------- pauseSendControl -------------
		when pauseSendControl =>
			load_control <= '1';			-- load control register value to the shifter			
			nextState <= sendControl;
			
			
		---------------- sendControl ----------------
		when sendControl =>
			ctr_inc <= '1';		-- increment counter, run 16 times
			ctr_reset <= '0';
			
			negedge <= '1';		-- use both edges
						
			shift_in <= '1';		-- shift in and out
			shift_out <= '1';		-- shift out on positive edge, shift in on negative edge
			codec_dout <= shiftOutRegister( 15 );
			
			if( counter = 15 ) then
				nextState <= syncSend;
			end if;
			
		
		------------------ syncSend -----------------
		when syncSend =>
			negedge <= '1';
			
			save_status <= '1';
			
			if( codec_sync = '1' ) then				
				nextState <= pauseSendData;
			end if;
			
			
		-------------- pauseSendData ---------------
		when pauseSendData =>
			load_dac <= '1';			
			nextState <= sendData;
			
			
		----------------- sendData -----------------
		when sendData =>
			ctr_inc <= '1';
			ctr_reset <= '0';
			
			negedge <= '1';
			
			shift_out <= '1';
			shift_in <= '1';
			codec_dout <= shift_msb;
			
			if( shift_in_done = '1' ) then
				nextState <= saveData;
			end if;
			
			
		----------------- saveData ------------------
		when saveData =>
			save_adc <= '1';
			
			nextState <= waitForSync;
		
		
		------------------ default ------------------
		when others =>
			nextState <= ResetState;
			
	end case;


end process ASYNC;


end Behavioral;

