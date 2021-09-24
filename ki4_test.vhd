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
			p_o_diap_13:	out std_logic;		-- сигнал о работе в первом или третьем поддиапазоне
			p_o_diap_24:	out std_logic;		-- сигнал о работе во втором или четвертом поддиапазоне
			p_o_diap_2:		out std_logic;		-- сигнал о работе во втором поддиапазоне			
			p_o_diap_4:		out std_logic;		-- сигнал о работе в четвертом поддиапазон	

			p_i_btn:		in std_logic 		-- линия проверки наличия питания синтезатора
		); 
end entity;



architecture behav of ki4_test is
	-- сигналы модулю управления
	SIGNAL s_RST: std_logic := '1';
	SIGNAL s_DIAP_CODE: std_logic_vector (1 downto 0) := "00";
	SIGNAL s_ZONE1: std_logic := '0';
	SIGNAL s_ZONE2: std_logic := '1';
	SIGNAL s_REV: std_logic := '0';
	SIGNAL s_SINT_POW: std_logic := '0';
	SIGNAL s_RST_FLAG: std_logic := '0';

	-- jtag modules
	SIGNAL s_TDO, s_TDI: std_logic;
	SIGNAL s_IR_IN, s_IR_OUT: std_logic_vector(2 downto 0);
	SIGNAL s_TCK, s_CDR, s_SDR, s_E1DR, s_PDR, s_E2DR, s_UDR, s_CIR, s_UIR: std_logic := '0';
	SIGNAL s_REG: std_logic_vector(7 downto 0) := x"00";


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

-- модуль jtag (управление от ПК)
	component jtag_unit is
		port (
			tdi                : out std_logic;                                       -- принятые входные данные
			tdo                : in  std_logic                    := 'X';             -- tdo
			ir_in              : out std_logic_vector(2 downto 0);                    -- текущая загркженная инструкция в модуль
			ir_out             : in  std_logic_vector(2 downto 0) := (others => 'X'); 
			virtual_state_cdr  : out std_logic;                                       
			virtual_state_sdr  : out std_logic;                                       -- строб получения из модуля JTAG бита данных ("1" - есть данные на выходе)
			virtual_state_e1dr : out std_logic;                                       
			virtual_state_pdr  : out std_logic;                                       
			virtual_state_e2dr : out std_logic;                                       
			virtual_state_udr  : out std_logic;                                       -- строб окончания приема данных
			virtual_state_cir  : out std_logic;                                       
			virtual_state_uir  : out std_logic;                                       
			tck                : out std_logic                                        -- тактовый сигнал модуля
		);
	end component jtag_unit;

begin

	ki4_control_unit: ki4_v2 port  map (	

 			p_i_clk 		=> p_i_clk,
		-- сигналы с внешнего разъема
			p_i_reset 		=> s_RST,
			p_i_diap_1 		=> s_DIAP_CODE(0),
			p_i_diap_2 		=> s_DIAP_CODE(1),
			p_i_zone_1		=> s_ZONE1,
			p_i_zone_2		=> s_ZONE2,
			p_i_reverse	 	=> s_REV,
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

			p_i_sint_power_on => s_SINT_POW
		);

	jtag_unit_module: jtag_unit port map (	tdi                => s_TDI,
											tdo                => s_TDO,
											ir_in              => s_IR_IN,
											ir_out             => s_IR_OUT,
											virtual_state_cdr  => s_CDR,
											virtual_state_sdr  => s_SDR,
											virtual_state_e1dr => s_E1DR,
											virtual_state_pdr  => s_PDR,
											virtual_state_e2dr => s_E2DR,
											virtual_state_udr  => s_UDR,
											virtual_state_cir  => s_CIR,
											virtual_state_uir  => s_UIR,
											tck                => s_TCK
										);


	-- прием данных оп JTAG (в регистре данный должен быть код 001)
	process (s_TCK) begin
		if rising_edge(s_TCK) then
		
			if s_SDR = '1' and s_IR_IN = "001" then
				s_REG <= s_TDI & s_REG(7 downto 1);
			end if;				
			
		end if;	
	end process;

	
	-- обработка данных для установки режима рбаоты синтезатора
	----------------------------------------------------------- 
	-- 					ТАБЛИЦА КОДОВ ОПЕРАЦИЙ
	-----------------------------------------------------------
	-- 00 	| 	сигнал питания синтезатора - ВЫКЛ
	-- 01 	| 	сигнал питания синтезатора - ВКЛ
	-- 02 	| 	реверс - ВЫКЛ
	-- 03 	| 	реверс - ВКЛ
	-- 04 	| 	сброс
	-- 05 	| 	диапазом 1
	-- 06 	| 	диапазом 2
	-- 07 	| 	диапазом 3
	-- 08 	| 	диапазом 4
	-- 09 	| 	ЗОНА 1 - '1'
	-- 0A 	| 	ЗОНА 1 - '0'
	-- 0B 	| 	ЗОНА 2 - '1'
	-- 0C 	| 	ЗОНА 2 - '0'






	process(p_i_clk) begin
		if rising_edge(p_i_clk) then

			if s_IR_IN = "001" then

				case s_REG is
					when X"00" =>	s_SINT_POW <= '0';
					when X"01" => 	s_SINT_POW <= '1';
					when X"02" => 	s_REV <= '0';
					when X"03" =>	s_REV <= '1';
					when X"04" => 	s_RST_FLAG <= '1';
					when X"05" => 	s_DIAP_CODE <= "00";
					when X"06" => 	s_DIAP_CODE <= "01";
					when X"07" => 	s_DIAP_CODE <= "10";
					when X"08" => 	s_DIAP_CODE <= "11";
					when X"09" => 	s_ZONE1 <= '1';
					when X"0A" => 	s_ZONE1 <= '0';
					when X"0B" => 	s_ZONE2 <= '1';
					when X"0C" => 	s_ZONE2 <= '0';

					when others => 	Null;

				end case;

			else
				s_TDO <= s_TDI;

			end if;
			

		end if;
	end process;



end architecture;