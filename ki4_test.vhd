library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ki4_test is
	port (p_i_clk:		in std_logic;
		
			p_i_main_tick:	in std_logic;		-- тактовые импульсы при перестроке частоты с шагом в два МГц (счетчик изменяется на 1 или 2 МГц в зависимости от поддиапазона
			p_o_end_diap:	out std_logic;		-- окончание диапазаона (формируется при достижении счетчиком максималльного значения) МЕТКА НД
			p_o_ak_sr_kp:	out std_logic; 		-- сингал окончания диапазона формируется синхронно с сигналом НД, но дополнительно может поступать с АК СР и КП

			-- сигналы управления синтезатором по SPI
			p_o_spi_cs:		out std_logic; 		-- строб передачи данных
			p_o_spi_clk:	out std_logic; 		-- тактовые импульсы
			p_o_spi_mosi:	out std_logic; 		-- данные
			
			-- сигналы управления внутренними частями блока
			p_o_diap_13:		out std_logic;		-- сигнал о работе в первом или третьем поддиапазоне
			p_o_diap_24:		out std_logic;		-- сигнал о работе во втором или четвертом поддиапазоне
			p_o_diap_2:			out std_logic;		-- сигнал о работе во втором поддиапазоне			
			p_o_diap_4:			out std_logic;		-- сигнал о работе в четвертом поддиапазон	

			p_i_btn:		in std_logic 		-- линия проверки наличия питания синтезатора
		); 
end entity;



architecture behav of ki4_test is

	SIGNAL s_BTN_PUSH: std_logic := '0';
	SIGNAL s_BTN_FILTER: std_logic_vector (3 downto 0) := "0000";
	SIGNAL s_COUNT: integer := 0;


	component ki4_v2 is
		port (	p_i_clk:		in std_logic;
			-- сигналы с внешнего разъема
				p_i_reset:		in std_logic;		-- сигнал сброса (низки уровень - сброс)
				p_i_diap_1:		in std_logic;		-- диапазон шина 1	// код поддиапазона (литеры)
				p_i_diap_2:		in std_logic;		-- диапалон шина 2
				p_i_zone_1:		in std_logic;		-- Зона 1 (Остановка счетчика ТИ, при поступлении ТИ счетчик не изменяет свое значение, СВЧ сигнал на выходе должен присутствовать, частота СВЧ сигнала не изменяется)
				p_i_zone_2:		in std_logic;		-- Зона 2 (Прекращение выдачи СВЧ сигнала, увеличение счетчика продолжается в соответствии с ТИ, при в=разрешении выдачи СВЧ, частота устанавливается в соответствии со знечением счетчика)		
				p_i_reverse:	in std_logic;		-- направление счета (инкремент/декремент)
				p_i_main_tick:	in std_logic;		-- тактовые импульсы при перестроке частоты с шагом в два МГц (счетчик изменяется на 1 или 2 МГц в зависимости от поддиапазона)
				p_i_cnt_tick:	in std_logic;		-- выбор инкремента счетчика (1/16)
				p_o_end_diap:	out std_logic;		-- окончание диапазаона (формируется при достижении счетчиком максималльного значения) МЕТКА НД
				p_o_ak_sr_kp:	out std_logic; 		-- сингал окончания диапазона формируется синхронно с сигналом НД, но дополнительно может поступать с АК СР и КП

				-- сигналы управления синтезатором по SPI
				p_o_spi_cs:		out std_logic; 		-- строб передачи данных
				p_o_spi_clk:	out std_logic; 		-- тактовые импульсы
				p_o_spi_mosi:	out std_logic; 		-- данные

				-- сигналы управления внутренними частями блока
				p_o_diap_13:		out std_logic;		-- сигнал о работе в первом или третьем поддиапазоне
				p_o_diap_24:		out std_logic;		-- сигнал о работе во втором или четвертом поддиапазоне
				p_o_diap_2:			out std_logic;		-- сигнал о работе во втором поддиапазоне			
				p_o_diap_4:			out std_logic;		-- сигнал о работе в четвертом поддиапазоне
				p_i_end_diap_from_res:	in std_logic;	-- сигнал о окончании диапазона от контрольных резонаторов (Срез)

				p_i_sint_power_on:	in std_logic 		-- линия проверки наличия питания синтезатора

			);
	end component ; -- ki4_upr

begin

	ki4_control_unit: ki4_v2 port  map (	

 			p_i_clk 		=> p_i_clk,
		-- сигналы с внешнего разъема
			p_i_reset 		=> '1',
			p_i_diap_1 		=> '0',
			p_i_diap_2 		=> '0',
			p_i_zone_1		=> '0',
			p_i_zone_2		=> '1',
			p_i_reverse	 	=> '1',
			p_i_main_tick	=> p_i_main_tick,
			p_i_cnt_tick  	=> '1',
			p_o_end_diap 	=> p_o_end_diap,
			p_o_ak_sr_kp 	=> p_o_ak_sr_kp,

			-- сигналы управления синтезатором по SPI
			p_o_spi_cs		=> p_o_spi_cs,
			p_o_spi_clk 	=> p_o_spi_clk,
			p_o_spi_mosi 	=> p_o_spi_mosi,

			-- сигналы управления внутренними частями блока
			p_o_diap_13 	=> p_o_diap_13,
			p_o_diap_24		=> p_o_diap_24,
			p_o_diap_2 		=> p_o_diap_2,
			p_o_diap_4 		=> p_o_diap_4,
			p_i_end_diap_from_res => '1',

			p_i_sint_power_on => s_BTN_PUSH
		);
	
	
	process(p_i_clk) begin
		if rising_edge(p_i_clk) then
			s_BTN_FILTER <= s_BTN_FILTER(2 downto 0) & p_i_btn;


			if s_BTN_FILTER = "1100" and s_COUNT = 0 then
				s_COUNT <= 100;
				s_BTN_PUSH <= '0';
			end if;

			if s_COUNT = 1 then
				s_BTN_PUSH <= '1';
				s_COUNT <= 0;
			elsif s_COUNT > 1 then
				s_COUNT <= s_COUNT - 1;
			end if;



		end if;
	end process;



end architecture;