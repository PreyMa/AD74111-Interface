--------------------------------------------------------------------------------
-- Company: 		HTBL-Hollabrunn
-- Engineer:		Matthias Preymann 5BHEL
--
-- Create Date:   18:48:12 09/12/2018
-- Design Name:   
-- Module Name:   C:/Xilinx/Projects/projekt/bodner/codec/TB_codec.vhd
-- Project Name:  codec
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: automat
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY TB_codec IS
END TB_codec;
 
ARCHITECTURE behavior OF TB_codec IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT automat
    PORT(
         control_mode : IN  std_logic;
         busy : OUT  std_logic;
         clock : IN  std_logic;
         enable : IN  std_logic;
         reset : IN  std_logic;
         set : IN  std_logic;
         pin : IN  std_logic_vector(23 downto 0);
         pout : OUT  std_logic_vector(23 downto 0);
         codec_sync : IN  std_logic;
         codec_din : IN  std_logic;
         codec_dout : OUT  std_logic;
         codec_reset : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal control_mode : std_logic := '0';
   signal clock : std_logic := '0';
   signal enable : std_logic := '0';
   signal reset : std_logic := '0';
   signal set : std_logic := '0';
   signal pin : std_logic_vector(23 downto 0) := (others => '0');
   signal codec_sync : std_logic := '0';
   signal codec_din : std_logic := '0';

 	--Outputs
   signal busy : std_logic;
   signal pout : std_logic_vector(23 downto 0);
   signal codec_dout : std_logic;
   signal codec_reset : std_logic;

   -- Clock period definitions
   constant clock_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: automat 
		PORT MAP (
          control_mode => control_mode,
          busy => busy,
          clock => clock,
          enable => enable,
          reset => reset,
          set => set,
          pin => pin,
          pout => pout,
          codec_sync => codec_sync,
          codec_din => codec_din,
          codec_dout => codec_dout,
          codec_reset => codec_reset
        );

   -- Clock process definitions
   clock_process :process
   begin
		clock <= '0';
		wait for clock_period/2;
		clock <= '1';
		wait for clock_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	
		
		reset <= '1';
      wait for clock_period*10;
		reset <= '0';
		enable <= '1';
		
		-- short pulse
		wait for clock_period*19.75;
		codec_sync <= '1';
		wait for clock_period/2;
		codec_sync <= '0';
		
		-- long pulse
		wait for clock_period*40;
		codec_sync <= '1';
		wait for clock_period/2;
		codec_sync <= '0';
		
		-- sync for control init
		wait for clock_period*90;
		codec_sync <= '1';
		wait for clock_period/2;
		codec_sync <= '0';
		
		
		-- sync ignore
		wait for clock_period*60;
		codec_sync <= '1';
		wait for clock_period/2;
		codec_sync <= '0';
		
		
		-- setup control register
		wait for clock_period*100;
		control_mode <= '1';
		set <= '1';
		pin <= "000000001001000000010000";
		
		-- setup data register
		wait for clock_period*10;
		control_mode <= '0';
		set <= '1';
		pin <= "000110101010101010101010";
		
		-- sync begin
		wait for clock_period*40;
		codec_sync <= '1';
		wait for clock_period/2;
		codec_sync <= '0';

      -- insert stimulus here 

      wait;
   end process;

END;
