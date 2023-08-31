=head
 NAME: TL_ARY_create_array_overlay
 DESCRIPTION: array边图形添加
 PARAMETER:
	{items => [
		{
			name=>'step_filter',
			label=>'工作Step过滤',
			type=>'string',
			must_field=>0,
			value => '',
			remark=>'工作step过滤，必须设定',
		},
		{
			name=>'units',
			label=>'工作单位',
			type=>'enum',
			property=>{
				tl_field=>[name=>'scalar',display_name=>'text'],
				tl_value_field=>'name',
				tl_data=>[
					{name=>'inch',display_name=>'inch'},
					{name=>'mm',display_name=>'mm'},
				]
			},
			remark=>'优先抓取脚本参数配置，如不设置，则抓取公共配置，公共配置也未设置，则默认为inch',
		},
		{
			name=>'outline',
			label=>'outline层别名称',
			type=>'string',
			must_field=>0,
			value => '',
			remark=>'如果未设置，默认用公共配置中的outline层名',
		},
		{
			name=>'fiducial_attribute',
			label=>'光学点属性',
			type=>'string',
			must_field=>1,
			value => '',
			remark=>"array-map层上将全部依属性区分物件,格式如：['smd',{attribute=>'.string',text=>'aaa'}],如不填写将默认为无光学点",
		},
		{
			name=>'tooling_hole_attribute',
			label=>'工具孔属性',
			type=>'string',
			must_field=>1,
			value => '',
			remark=>"array-map层上将全部依属性区分物件,格式如：['smd',{attribute=>'.string',text=>'aaa'}]，如不填写将默认为无工具孔",
		},
		{
			name=>'pn_attribute',
			label=>'料号名属性',
			type=>'string',
			must_field=>1,
			value => '',
			remark=>"array-map层上将全部依属性区分物件,格式如：['smd',{attribute=>'.string',text=>'aaa'}]，如不填写将默认为无料号名",
		},
		#{
		#	name=>'only_copper',
		#	label=>'是否仅铺铜',
		#	type=>'radio',
		#	property=>{
		#		tl_columns=>2,
		#		tl_list=>['yes'=>'YES','no'=>'NO'],
		#	},
		#	must_field=>1,
		#	value=>'yes',
		#},
	]}
	
 VERSION_HISTORY:
	V1.00 2015-12-17 Cody Yu
	   1.新版本
		
		
 HELP:
	<html><body bgcolor="#DDECFE">
		<font size="3" color="#003DB2"><p>功能简介</p></font>
		  <p> array边图形添加 </p>
		  <br>
		<font size="3" color="#003DB2"><p>参数配置</p></font>
		 <p> ● 无</p>
		<font size="3" color="#003DB2"><p>注意事项</p></font>
		  <p> ● 无 </p>
		  <br>
	</body></html>
  
=cut

use strict;
use utf8;
use Encode;
use Data::Dump 'dump';
use StdPubConfig;
use StdPubFunction;
#$APP,$DB2,$PAR,$JOB,$JOB_ID,$DB,$GUI,$self,$GEN,$DB_MAIL,$GEN_TYPE,$USER_NAME,$STEP
my %M_PAR = (GEN=>$GEN,GUI=>$GUI,DB=>$DB);
my $C = StdPubConfig->new(%M_PAR);
my $F = StdPubFunction->new(%M_PAR);
my $Job = $JOB;
$PAR->{units} = $PAR->{units} || $C->get_units()||'inch';
$PAR->{array_map} = 'array-map';
$PAR->{array_map_tmp} = 'array-map_tmp';
$PAR->{outline} = $PAR->{outline} || $C->get_outline_name();
my %MAP;

try{
	##判断tl_string属性是否存在
	my $ans = IsAttrExist(file=>$ENV{GENESIS_DIR}.'/fw/lib/misc/userattr',attr_name=>'tl_string');
	unless($ans){
		$GUI->msgbox(-icon=>'warning',-text=>'请先在系统中建立tl_string属性(可参考系统属性.string)');
		return 'Cancel';
	}
	##
	unless( $PAR->{step_filter} ){
		$GUI->msgbox(-icon=>'warning',-text=>'脚本参数中工作step必须设定！');
		return 'Cancel';
	}
	##
	$F->openJob($Job);
	##判断脚本参数
	#unless( $PAR->{fiducial_attribute} or $PAR->{tooling_hole_attribute} or $PAR->{pn_attribute} ){
	#	$GUI->msgbox(-icon=>'warning',-text=>'脚本参数中属性全部未设置，将会执行铺铜操作');
	#}
	##
	$PAR->{layer_count} = $DB->get_jobinfo(-jobname=>$JOB,-jobcategory=>'work',-jobinfo=>'tl_layer_count') || $GEN->getSelectCount();
	##判断array-map层是否存在
	#unless ( $PAR->{only_copper} eq 'no' or $GEN->isLayerExists(job=>$Job,layer=>$PAR->{array_map}) ) {
	#	$GUI->msgbox(-icon=>'warning',-text=>$PAR->{array_map}.'层不存在，无法添加各层array边图形');
	#	return 'Cancel';
	#}
	##
	show_loading("过滤工作step。。。",0,position=>'n');
	my @steps = $F->getStep(jobname=>$Job,step_filter=>$PAR->{step_filter});
	return 'Cancel' if($steps[0] eq 'Cancel');
	
	
	##制作
	foreach my $step (@steps) {
		###Open step and clear layer
		$F->openStep(job=>$Job,name=>$step,units=>$PAR->{units});
		###Open step and clear layer
		update_loading("$step step中制作array-map层",0,position=>'n');
		if ( $GEN->isLayerExists(job=>$Job,layer=>$PAR->{array_map}) and $GEN->isLayerEmpty( job=>$Job,step=>$step,layer=>$PAR->{array_map}) ){
			update_loading("$step step中$PAR->{array_map} 层为空，无法添加各层array边图形",0,position=>'n');
			$GUI->msgbox(-icon=>'info',-text=>"$step step中$PAR->{array_map} 层为空，无法添加各层array边图形");
			if($step eq $steps[-1]){
				return 'Cancel';
			}
			else{
				next;
			}
		}
		my %matrix = $GEN->getMatrix(job=>$Job,type=>'hash');
		##
		my @work_layers = $GUI->select_layer(-title=>"请选择$step 中需添加图形的层别",
							-layermatrix=>\%matrix,
							-default => [],
							-selectmode => 'multiple',
							-context=>'board',);#single
		return 'Cancel' unless @work_layers;
		
		##解析array-map层上信息
		check_map_info(step=>$step,matrix=>\%matrix,array_map=>$PAR->{array_map},layers=>\@work_layers);
		
		##如果选择了非信号层且未设定属性，则报告
		unless( $PAR->{fiducial_attribute} or $PAR->{tooling_hole_attribute} or $PAR->{pn_attribute} ){
			foreach my $layer(@work_layers){
				next if $matrix{$layer}{tl_type} =~ /(inner|dip|outer)/;
				$GUI->msgbox(-icon=>'warning',-text=>'脚本参数属性全部未设置，选择的层中将只有信号层制作铺铜，其他层忽略处理');
				last;
			}
		}
		
		##确认参数
		update_loading("确认参数",0,position=>'n');
		my $info = confirm_ui(step=>$step,matrix=>\%matrix,layers=>\@work_layers);
		return $info if $info eq 'Cancel';
		
		##各层array overlay制作
		$info = create_array_overlay(step=>$step,matrix=>\%matrix,layers=>\@work_layers,info=>$info);
		return $info if $info;
		
		$GEN->deleteLayer(job=>$Job,layer=>[$PAR->{array_map_tmp}],step=>$step);
		$GEN->clearLayers();
		$GEN->affectedLayer( mode=>'all',affected=>'no' );
		$GEN->closeStep() unless $step eq $steps[-1];
	}
	
	$F->script_end_msgbox(text=>'array overlay各层制作完成，请继续编辑！',type=>$C->get_end_msgbox_type());
	
	###output and return status, if genesis error, it will output genesis error command
	unless ($GEN->{STATUS}){
		return 'done';
	}
	else{
		$GUI->msgbox(-icon=>'error',-text=>join("\n",@{$GEN->{STATUS}}));
		addFlowNotes(-notes=>"   Genesis Error:\n   ".join("\n   ",@{$GEN->{STATUS}}));
		return 'Error';
	}
}
catch Error::Simple with {
	my $error = encode("utf8",shift);
	$GUI->msgbox(-icon=>'error',-text=>$error);
	return 'Error';
}
finally{
	
};

sub IsAttrExist{
	my %par = @_;
	my $exist = 0;;
	open (my $in, $par{file}) or die "open error: $! "; 
	my @lines;
	while(<$in>){
		chomp;
		push @lines,$_;
	}
	close($in);
	my $row = 0;
	foreach my $line(@lines){
		chomp;
		if( $line =~ /name\s*\=\s*$par{attr_name}/i ){
			$exist = 1;
			last;
		}
		$row++;
	}
	return $exist;
}

sub check_map_info{
	my %par = @_;
	my %matrix = %{$par{matrix}};
	if ( $GEN->isLayerExists(job=>$Job,layer=>$PAR->{array_map}) ) {
		$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
		##检查是否有光学点
		if( $PAR->{fiducial_attribute} ){
			$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}),);
			if ( $GEN->getSelectCount() > 0 ){
				$MAP{map_fiducial_exist} = 1;
				$GEN->selClearFeature();
			}
		}
		##检查是否有工具孔
		if( $PAR->{tooling_hole_attribute} ){
			$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}),);
			if ( $GEN->getSelectCount() > 0 ){
				$MAP{map_tooling_hole_exist} = 1;
				$GEN->selClearFeature();
			}
		}
		##检查是否有料号名
		if( $PAR->{pn_attribute} ){
			$GEN->selectByFilter(attribute=>eval($PAR->{pn_attribute}),);
			if ( $GEN->getSelectCount() > 0 ){
				$MAP{map_pn_exist} = 1;
				$GEN->selClearFeature();
			}
		}
		##检查是否有其他物件
		$GEN->COM('sel_all_feat');
		$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}),operation=>'unselect')if( $PAR->{fiducial_attribute} );
		$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}),operation=>'unselect')if( $PAR->{tooling_hole_attribute} );
		$GEN->selectByFilter(attribute=>eval($PAR->{pn_attribute}),operation=>'unselect')if( $PAR->{pn_attribute} );
		if ( $GEN->getSelectCount() > 0 ){
			$MAP{map_other_exist} = 1;
			$GEN->selClearFeature();
		}
	}
	$GEN->deleteLayer(job=>$Job,layer=>[$PAR->{array_map_tmp}],step=>$par{step});
	##检查客户正式信号层和钻孔层上是否有原始物件
	foreach my $layer (sort {$matrix{$a}{row} <=> $matrix{$b}{row}}  keys %matrix) {
		next unless $matrix{$layer}{context} eq 'board';
		next unless ($matrix{$layer}{tl_type} =~ /(inner|dip|outer)/ or ($matrix{$layer}{layer_type} =~ /(drill)/ and $matrix{$layer}{drl_start_num} == 1 and $matrix{$layer}{drl_end_num} == $PAR->{layer_count}));
		$GEN->affectedLayer(affected=>'yes',layer=>[$layer],clear_before=>'yes');
		##检查光学点
		if( $PAR->{fiducial_attribute} ){
			$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}),);
			$GEN->selectByFilter(attribute=>[{attribute=>'tl_string',text=>'*'}],operation=>'unselect');
			if ( $GEN->getSelectCount() > 0 ){
				$GEN->selCopyOther(target_layer=>$PAR->{array_map_tmp},invert=>'no');
				$MAP{$layer}{tooling_hole_exist} = 1;
				$MAP{tmp_fiducial_exist} = 1 unless $MAP{tmp_fiducial_exist};
			}
		}
		##检查工具孔
		if( $matrix{$layer}{layer_type} =~ /(drill)/ and $matrix{$layer}{drl_start_num} == 1 and $matrix{$layer}{drl_end_num} == $PAR->{layer_count} ){
			if( $PAR->{tooling_hole_attribute} ){
				$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}),);
				$GEN->selectByFilter(attribute=>[{attribute=>'.drill',option=>'non_plated'}],polarity=>'positive');
				$GEN->selectByFilter(attribute=>[{attribute=>'tl_string',text=>'*'}],operation=>'unselect');
				if ( $GEN->getSelectCount() > 0 ){
					$GEN->selCopyOther(target_layer=>$PAR->{array_map_tmp},invert=>'no');
					$MAP{$layer}{tooling_hole_exist} = 1;
					$MAP{tmp_tooling_hole_exist} = 1 unless $MAP{tmp_tooling_hole_exist};
					$GEN->selClearFeature();
				}
			}
		}
		##检查其他物件
		$GEN->COM('sel_all_feat');
		$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}),operation=>'unselect')if( $PAR->{fiducial_attribute} );
		$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}),operation=>'unselect')if( $PAR->{tooling_hole_attribute} );
		#$GEN->selectByFilter(attribute=>eval($PAR->{pn_attribute}),operation=>'unselect')if( $PAR->{pn_attribute} );
		$GEN->selectByFilter(attribute=>[{attribute=>'tl_string',text=>'*'}],operation=>'unselect');
		if ( $GEN->getSelectCount() > 0 ){
			$MAP{$layer}{other_exist} = 1;
			$GEN->selClearFeature();
		}
		if( $matrix{$layer}{layer_type} =~ /(drill)/ and $matrix{$layer}{drl_start_num} == 1 and $matrix{$layer}{drl_end_num} == $PAR->{layer_count} ){
			push @{$MAP{drills}},$layer;
		}
	}
	##
	foreach my $layer( @{$par{layers}}){
		$MAP{fiducial_exist} = 1 if($MAP{$layer}{fiducial_exist});
		$MAP{tooling_hole_exist} = 1 if($MAP{$layer}{tooling_hole_exist});
		#$MAP{other_exist} = 1 if($MAP{$layer}{other_exist});
	}
	##
	$GEN->clearLayers();
	$GEN->affectedLayer( mode=>'all',affected=>'no' );
}

sub confirm_ui{
	my %par = @_;
	my %matrix = %{$par{matrix}};
	##
	my (@drill,@signal,@sm,@ss,@inner,@outer);
	foreach my $layer(@{$par{layers}}){
		push @inner,$layer if $matrix{$layer}{tl_type} =~ /(inner|dip)/;
		push @outer,$layer if $matrix{$layer}{tl_type} =~ /(outer)/;
		push @signal,$layer if $matrix{$layer}{tl_type} =~ /(inner|outer|dip)/;
		push @drill,$layer if ($matrix{$layer}{layer_type} =~ /drill/ and $matrix{$layer}{drl_start_num} == 1 and $matrix{$layer}{drl_end_num} == $PAR->{layer_count});
		push @sm,$layer if $matrix{$layer}{layer_type} =~ /(solder_mask)/;
		push @ss,$layer if $matrix{$layer}{layer_type} =~ /(silk_screen)/;
	}
	my @items = (
		{
			n_columns=>1,
			label_property=>{xalign=>1},
			type=>'title',
			property=>{
				title=>'基本信息确认：',
				show_expander=>1,
			},
		},
		{
			name=>'units',
			label=>'单位',
			type=>'enum',
			property=>{
				tl_field=>[name=>'scalar',display_name=>'text'],
				tl_value_field=>'name',
				tl_data=>[
					{name=>'inch',	display_name=>'inch'},
					{name=>'mil',	display_name=>'mil'},
					{name=>'mm',	display_name=>'mm'},
					{name=>'um',	display_name=>'um'},
				]
			},
			remark=>'单位',
			sensitive =>0,
			value=>$PAR->{units},
			validate_func=>sub{
				my %par = @_;
				return {} if $par{mode} eq 'save';
				my $fill_copper = $par{formpanel}->get_widget('fill_copper');
				if ($par{mode} eq 'save') {
					$par{formpanel}->set_value('units',$C->get_units());
					$par{formpanel}->set_units($C->get_units());
					$fill_copper->set_units($C->get_units()) if @signal;
				}
				else{
					$par{formpanel}->set_units($par{value});
					$fill_copper->set_units($par{value}) if @signal;
				}
				return {}
			},
		},
	);
	if(@signal){
		unless ( $PAR->{outline} ) {
			hide_loading();
			$GUI->msgbox(-icon=>'warning',-text=>'选择有信号层，需铺铜但未定义outline层名称，请在脚本参数或公共配置中设置！');
			return 'Cancel';
		}
		unless ( $GEN->isLayerExists(job=>$Job,layer=>$PAR->{outline}) ) {
			hide_loading();
			$GUI->msgbox(-icon=>'warning',-text=>'选择有信号层，需铺铜但outline层不存在，请检查资料是否正确！');
			return 'Cancel';
		}
		if ( $GEN->isLayerEmpty( job=>$Job,step=>$par{step},layer=>$PAR->{outline}) ){
			hide_loading();
			$GUI->msgbox(-icon=>'warning',-text=>'选择有信号层，需铺铜但outline层上无外形，请检查资料是否正确！');
			return 'Cancel';
		}
		my ($n,%rows,@item_copper);
		foreach my $layer(@signal){
			$n++;
			$rows{$layer}{sequence} = $n;
			$rows{$layer}{layer} = $layer;
			$rows{$layer}{fill_type} = '';
			$rows{$layer}{fill_to_rout} = '';
			$rows{$layer}{fill_to_fid} = '' if($MAP{map_fiducial_exist} or $MAP{tmp_fiducial_exist});
			$rows{$layer}{fill_to_hole} = '' if($MAP{map_tooling_hole_exist} or $MAP{tmp_tooling_hole_exist} );
			$rows{$layer}{fill_to_other} = '' if($MAP{map_other_exist} or $MAP{$layer}{other_exist});
		}
		##
		push @item_copper,(
			{
				column_name=>'layer',
				label=>'层别',
				width=>50,
				type=>'label',
			},
			{
				column_name=>'fill_type',
				label=>'铺铜类型',
				width=>100,
				type=>'enum',
				property=>{
					tl_field=>[name=>'scalar',display_name=>'text'],
					tl_value_field=>'name',
					tl_data=>[
						#{name=>'na',display_name=>'NA'},
						{name=>'copper',display_name=>'实铜'},
						{name=>'cross',display_name=>'网格'},
					]
				},
				validate_func=>sub{
					my %par = @_;
					return if $par{mode} eq 'save';
					my $layer = $par{formpanel}->get_value($par{row},'layer');
					my $value = $par{formpanel}->get_value($par{row},'fill_type');
					#外层最上面内层自动更改同样类型的工具
					my $ref_layer = $outer[0];
					if ($layer eq $ref_layer){
						foreach my $same_tooling(@outer){
							next if($same_tooling eq $ref_layer);
							$par{formpanel}->set_value($same_tooling,'fill_type',$value);
						}
					}
					#内层最上面内层自动更改同样类型的工具
					$ref_layer = $inner[0];
					if ($layer eq $ref_layer){
						foreach my $same_tooling(@inner){
							next if($same_tooling eq $ref_layer);
							$par{formpanel}->set_value($same_tooling,'fill_type',$value);
						}
					}
					return {};
				}
			},
			{
				column_name=>'fill_to_rout',
				label=>'外形到铜',
				width=>100,
				type=>'units_number',
				validate_func=>sub{
					my %par = @_;
					return if $par{mode} eq 'save';
					my $layer = $par{formpanel}->get_value($par{row},'layer');
					my $value = $par{formpanel}->get_value($par{row},'fill_to_rout');
					#外层最上面层自动更改同样类型的工具
					my $ref_layer = $outer[0];
					if ($layer eq $ref_layer){
						foreach my $same_tooling(@outer){
							next if($same_tooling eq $ref_layer);
							$par{formpanel}->set_value($same_tooling,'fill_to_rout',$value);
						}
					}
					#内层最上面层自动更改同样类型的工具
					$ref_layer = $inner[0];
					if ($layer eq $ref_layer){
						foreach my $same_tooling(@inner){
							next if($same_tooling eq $ref_layer);
							$par{formpanel}->set_value($same_tooling,'fill_to_rout',$value);
						}
					}
					return {};
				}
			},
			{
				column_name=>'fill_to_fid',
				label=>'光学点到铜',
				width=>100,
				type=>'units_number',
				validate_func=>sub{
					my %par = @_;
					return if $par{mode} eq 'save';
					my $layer = $par{formpanel}->get_value($par{row},'layer');
					my $value = $par{formpanel}->get_value($par{row},'fill_to_fid');
					#外层最上面层自动更改同样类型的工具
					my $ref_layer = $outer[0];
					if ($layer eq $ref_layer){
						foreach my $same_tooling(@outer){
							next if($same_tooling eq $ref_layer);
							$par{formpanel}->set_value($same_tooling,'fill_to_fid',$value);
						}
					}
					#内层最上面层自动更改同样类型的工具
					$ref_layer = $inner[0];
					if ($layer eq $ref_layer){
						foreach my $same_tooling(@inner){
							next if($same_tooling eq $ref_layer);
							$par{formpanel}->set_value($same_tooling,'fill_to_fid',$value);
						}
					}
					return {};
				}
			},
			{
				column_name=>'fill_to_hole',
				label=>'孔到铜',
				width=>100,
				type=>'units_number',
				validate_func=>sub{
					my %par = @_;
					return if $par{mode} eq 'save';
					my $layer = $par{formpanel}->get_value($par{row},'layer');
					my $value = $par{formpanel}->get_value($par{row},'fill_to_hole');
					#外层最上面内层自动更改同样类型的工具
					my $ref_layer = $outer[0];
					if ($layer eq $ref_layer){
						foreach my $same_tooling(@outer){
							next if($same_tooling eq $ref_layer);
							$par{formpanel}->set_value($same_tooling,'fill_to_hole',$value);
						}
					}
					#内层最上面内层自动更改同样类型的工具
					$ref_layer = $inner[0];
					if ($layer eq $ref_layer){
						foreach my $same_tooling(@inner){
							next if($same_tooling eq $ref_layer);
							$par{formpanel}->set_value($same_tooling,'fill_to_hole',$value);
						}
					}
					return {};
				}
			},
			{
				column_name=>'fill_to_other',
				label=>'其他图形到铜',
				width=>100,
				type=>'units_number',
				validate_func=>sub{
					my %par = @_;
					return if $par{mode} eq 'save';
					my $layer = $par{formpanel}->get_value($par{row},'layer');
					my $value = $par{formpanel}->get_value($par{row},'fill_to_other');
					#外层最上面内层自动更改同样类型的工具
					my $ref_layer = $outer[0];
					if ($layer eq $ref_layer){
						foreach my $same_tooling(@outer){
							next if($same_tooling eq $ref_layer);
							$par{formpanel}->set_value($same_tooling,'fill_to_other',$value);
						}
					}
					#内层最上面内层自动更改同样类型的工具
					$ref_layer = $inner[0];
					if ($layer eq $ref_layer){
						foreach my $same_tooling(@inner){
							next if($same_tooling eq $ref_layer);
							$par{formpanel}->set_value($same_tooling,'fill_to_other',$value);
						}
					}
					return {};
				}
			},
		);
		##
		push @items,(
			{
				name=>'fram2',
				n_columns=>1,
				label_property=>{xalign=>1},
				type=>'title',
				property=>{
					title=>'铺铜信息确认：',
					show_expander=>1,
				},
			},
			{
				name => 'fill_copper',
				class => 'TL::Gtk2::TableFormPanel',
				property => {
					tl_rows  => \%rows,
					tl_columns =>[
						@item_copper
					],
				},
				expand=>1,
				change_signal => 'data_changed',
				validate_func=>sub{
					my %par = @_;
					#return {} unless($par{mode} eq 'load');
					my $data = $par{widget}->get_all_value();
					$par{widget}->signal_connect('data_changed'=>sub{
						$data = $par{widget}->get_all_value();
						my $cross;
						foreach my $row_name (%$data){
							if($data->{$row_name}{fill_type} eq 'cross'){
								$cross = 1;
								last;
							}
						}
						if($cross){
							my $ver = $GEN->getGenVersion(type=>'number');
							if($ver < 97){
								return {error_msg=>'当前genesis版本过低，无法使用自动铺网格功能'};
							}
							$par{formpanel}->set_item_visible('cross_line'=>1,);
							$par{formpanel}->set_item_visible('cross_space'=>1,);
							$par{formpanel}->set_item_visible('cross_outline'=>1,);
						}
						else{
							$par{formpanel}->set_item_visible('cross_line'=>0,);
							$par{formpanel}->set_item_visible('cross_space'=>0,);
							$par{formpanel}->set_item_visible('cross_outline'=>0,);
						}
					});
					my $units = $par{formpanel}->get_value('units');
					$par{widget}->set_units($units);
					##
					my $cross;
					foreach my $row_name (%$data){
						if($data->{$row_name}{fill_type} eq 'cross'){
							$cross = 1;
							last;
						}
					}
					if($cross){
						my $ver = $GEN->getGenVersion(type=>'number');
						if($ver < 97){
							return {error_msg=>'当前genesis版本过低，无法使用自动铺网格功能'};
						}
						$par{formpanel}->set_item_visible('cross_line'=>1,);
						$par{formpanel}->set_item_visible('cross_space'=>1,);
						$par{formpanel}->set_item_visible('cross_outline'=>1,);
					}
					else{
						$par{formpanel}->set_item_visible('cross_line'=>0,);
						$par{formpanel}->set_item_visible('cross_space'=>0,);
						$par{formpanel}->set_item_visible('cross_outline'=>0,);
					}
					##
					return {};
				},
				get_value_func => sub{my %par = @_;return $par{widget}->get_all_value();},
				set_value_func => sub{
					my %par = @_;
					my $data = $par{value};
					foreach my $row_name (%$data){
						foreach my $col_name (%{$data->{$row_name}}){
							$par{widget}->set_value($row_name,$col_name,$data->{$row_name}{$col_name});
						}
					}
				},
			},
			{
				name=>'cross_line',
				label=>'网格线宽',
				type=>'units_number',
			},
			{
				name=>'cross_space',
				label=>'网格中心距',
				type=>'units_number',
				oneline=>1,
			},
			{
				name=>'cross_outline',
				label=>'网格外形线宽',
				type=>'units_number',
				oneline=>1,
			},
		);
	}
	my @layer_fid;
	push @layer_fid,'outer'=>'外层' if @signal;
	push @layer_fid,'sm'=>'防焊层' if @sm;
	##添加光学点
	if( $MAP{map_fiducial_exist} and @layer_fid ){
		#my (@drill,@signal,@sm,@ss);
		#my @layer_fid = ('outer'=>'外层','sm'=>'防焊层');
		push @items,(
			{
				name=>'fram3',
				n_columns=>1,
				label_property=>{xalign=>1},
				type=>'title',
				property=>{
					title=>'光学点添加确认：',
					show_expander=>1,
				},
			},
			{
				name=>'fid_add_layer',
				label=>'光学点添加层',
				type => 'checkbox',
				value=>['outer','sm'],
				must_field=>1,
				property=>{
					tl_columns => 2,
					tl_list=>\@layer_fid,
				},
			},
			{
				name=>'fid_outer',
				label=>'光学点外层symbol',
				type=>'string',
				must_field=>1,
				visible_func => sub{
					my %par = @_;
					my $value = $par{formpanel}->get_value('fid_add_layer');
					if($value and grep{$_ eq 'outer'}@{$value}){
						return 'show';
					}
					else{
						return 'hide';
					}
				},
				#validate_func=>sub{
				#	my %par = @_;
				#	return {} if $par{mode} eq 'load';
				#	return {} unless $par{value};
				#	unless ($par{value} =~ /^\d+(\.\d+)?$/ or $par{value} =~ /^(\+|\-)\d+(\.\d+)?$/){
				#		return {
				#			bgcolor=>'red',
				#			error_msg=>'光学点外层值设置错误格式',
				#		}
				#	}
				#	return {}
				#},
			},
			{
				name=>'fid_sm',
				label=>'光学点防焊symbol',
				type=>'string',
				must_field=>1,
				visible_func => sub{
					my %par = @_;
					my $value = $par{formpanel}->get_value('fid_add_layer');
					if($value and grep{$_ eq 'sm'}@{$value}){
						return 'show';
					}
					else{
						return 'hide';
					}
				},
				#validate_func=>sub{
				#	my %par = @_;
				#	return {} if $par{mode} eq 'load';
				#	return {} unless $par{value};
				#	unless ($par{value} =~ /^\d+(\.\d+)?$/ or $par{value} =~ /^(\+|\-)\d+(\.\d+)?$/){
				#		return {
				#			bgcolor=>'red',
				#			error_msg=>'光学点外层值设置错误格式',
				#		}
				#	}
				#	return {}
				#},
			},
		);
	}
	my @layer_hole;
	push @layer_hole,'sm'=>'防焊层' if @sm;
	push @layer_hole,'drill'=>'钻孔层' if @drill;
	if( $MAP{map_tooling_hole_exist} and @layer_hole ){
		##tooling孔
		push @items,(
			{
				name=>'fram3',
				n_columns=>1,
				label_property=>{xalign=>1},
				type=>'title',
				property=>{
					title=>'工具孔添加确认：',
					show_expander=>1,
				},
			},
			{
				name=>'hole_add_layer',
				label=>'工具孔添加层',
				type => 'checkbox',
				value=>['drill','sm'],
				must_field=>1,
				property=>{
					tl_columns => 2,
					tl_list=>\@layer_hole,
				},
			},
			{
				name=>'hole_drill',
				label=>'工具孔钻孔symbol',
				type=>'string',
				must_field=>1,
				visible_func => sub{
					my %par = @_;
					my $value = $par{formpanel}->get_value('hole_add_layer');
					if($value and grep{$_ eq 'drill'}@{$value}){
						return 'show';
					}
					else{
						return 'hide';
					}
				},
				#validate_func=>sub{
				#	my %par = @_;
				#	return {} if $par{mode} eq 'load';
				#	return {} unless $par{value};
				#	unless ($par{value} =~ /^\d+(\.\d+)?$/ or $par{value} =~ /^(\+|\-)\d+(\.\d+)?$/){
				#		return {
				#			bgcolor=>'red',
				#			error_msg=>'光学点外层值设置错误格式',
				#		}
				#	}
				#	return {}
				#},
			},
			{
				name=>'hole_sm',
				label=>'工具孔防焊symbol',
				type=>'string',
				must_field=>1,
				visible_func => sub{
					my %par = @_;
					my $value = $par{formpanel}->get_value('hole_add_layer');
					if($value and grep{$_ eq 'sm'}@{$value}){
						return 'show';
					}
					else{
						return 'hide';
					}
				},
				#validate_func=>sub{
				#	my %par = @_;
				#	return {} if $par{mode} eq 'load';
				#	return {} unless $par{value};
				#	unless ($par{value} =~ /^\d+(\.\d+)?$/ or $par{value} =~ /^(\+|\-)\d+(\.\d+)?$/){
				#		return {
				#			bgcolor=>'red',
				#			error_msg=>'光学点外层值设置错误格式',
				#		}
				#	}
				#	return {}
				#},
			},
		);
	}
	my @layer_pn;
	push @layer_pn,'outer'=>'外层' if @signal;
	push @layer_pn,'sm'=>'防焊层' if @sm;
	push @layer_pn,'ss'=>'文字层' if @ss;
	if( $MAP{map_pn_exist} and @layer_pn ){
		##料号名
		push @items,(
			{
				name=>'fram3',
				n_columns=>1,
				label_property=>{xalign=>1},
				type=>'title',
				property=>{
					title=>'料号名添加确认：',
					show_expander=>1,
				},
			},
			{
				name=>'pn_add_layer',
				label=>'料号名添加层',
				type => 'checkbox',
				#value=>[],
				must_field=>1,
				property=>{
					tl_columns => 3,
					tl_list=>\@layer_pn,
				},
			},
			{
				name=>'pn_outer_polarity',
				label=>'外层料号名极性',
				type => 'enum',
				property=>{
					tl_field=>[name=>'scalar',display_name=>'text'],
					tl_value_field=>'name',
					tl_data=>[
						{name=>'positive',display_name=>'positive'},
						{name=>'negative',display_name=>'negative'},
					],
				},
				must_field=>1,
				visible_func => sub{
					my %par = @_;
					my $value = $par{formpanel}->get_value('pn_add_layer');
					if($value and grep{$_ eq 'outer'}@{$value}){
						return 'show';
					}
					else{
						return 'hide';
					}
				},
			},
			{
				name=>'pn_outer_space',
				label=>'外层料号底铜到文字距离',
				type => 'units_number',
				must_field=>1,
				oneline=>1,
				visible_func => sub{
					my %par = @_;
					my $value = $par{formpanel}->get_value('pn_add_layer');
					if($value and grep{$_ eq 'outer'}@{$value}){
						return 'show';
					}
					else{
						return 'hide';
					}
				},
			},
			{
				name=>'pn_sm',
				label=>'料号名开窗大小(单侧)',
				type=>'units_number',
				must_field=>1,
				value=>'',
				visible_func => sub{
					my %par = @_;
					my $value = $par{formpanel}->get_value('pn_add_layer');
					my $value2 = $par{formpanel}->get_value('pn_outer_polarity');
					if($value and grep{$_ eq 'outer'}@{$value} and @sm and $value2 eq 'positive'){
						return 'show';
					}
					else{
						return 'hide';
					}
				},
			},
		);
	}
	
	##
	my $file = $GEN->getJobPath(job=>$Job).'/user/array_overlay_info';
	my %info = $GUI->show_form(
		-title => '请确认参数',
		-showcheck => 1,-gen=>$GEN,
		-defaultsize=>[750,550],-columns =>'1',
		-excludehideitem=>1,
		-buttons=>[
			{
				response=>'help',
				stock=>'暂停/查看',
				command=>sub{
					my %par = @_;
					$par{dialog}->hide;
					refresh_ui();
					my $ans = $GEN->PAUSE('Please Check');
					if( $ans eq 'OK'){
						$par{dialog}->show;
						refresh_ui();
					}
					else{
						exit;
					}
				}
			},
			{
				response=>'apply',
				stock=>'载入上次填入值',
				command=>sub{
				   my %par = @_;
				   $par{formpanel}->load_data(do($file)) if -f $file;
				}
			},
			{response=>'ok',stock=>'gtk-ok'},
			{response=>'cancel',stock=>'gtk-cancel'},
		],
		-items=>\@items,
	);
	return 'Cancel' unless %info;
	##存入信息文件
	open(my $fh,'>',$file); print $fh dump(\%info); close $fh;
	
	##
	
	#
	return \%info;
}

sub create_array_overlay{
	my %par = @_;
	my %matrix = %{$par{matrix}};
	my %info = %{$par{info}};
	foreach my $layer(@{$par{layers}}){
		$GEN->affectedLayer(affected=>'yes',layer=>[$layer],clear_before=>'yes');
		$GEN->selectByFilter(attribute=>[{attribute=>'tl_string',text=>'*'}],);
		$GEN->selDelete() if ( $GEN->getSelectCount() > 0 );
		if( $matrix{$layer}{tl_type} =~ /(inner|dip|outer)/ ){
			my $tmp_copper = $layer.'_copper_tmp';
			$GEN->createLayer(job=>$Job,layer=>$tmp_copper,context=>'misc',type=>'document',delete_exists=>'yes');
			$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_copper],clear_before=>'yes');
			##先铺铜
			$GEN->srFill(layer=>$tmp_copper,sr_margin_x=>$info{fill_copper}{$layer}{fill_to_rout}||0,sr_margin_y=>$info{fill_copper}{$layer}{fill_to_rout}||0,step_max_dist_x=>$PAR->{units} eq 'inch' ? 100 : 2540,step_max_dist_x=>$PAR->{units} eq 'inch' ? 100 : 2540,);
			##外形避铜
			my $tmp_outline = $layer.'_outline_tmp';
			$GEN->flattenLayer(source_layer=>$PAR->{outline},target_layer=>$tmp_outline);
			$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_outline],clear_before=>'yes');
			$GEN->selectByFilter(feat_types=>'line\;arc',polarity=>'positive',profile=>'all');
			if ( $GEN->getSelectCount() > 0 ){
				$GEN->selChangeSym(symbol=>'r'.$info{fill_copper}{$layer}{fill_to_rout}*2000);
				$GEN->selectByFilter(feat_types=>'line\;arc',polarity=>'positive',profile=>'all');
				$GEN->selCopyOther(target_layer=>$tmp_copper,invert=>'yes');
			}
			##光学点避铜
			if( $MAP{map_fiducial_exist} or $MAP{tmp_fiducial_exist} ){
				my $resize = $info{fill_copper}{$layer}{fill_to_fid} || 0;
				if ( $GEN->isLayerExists(job=>$Job,layer=>$PAR->{array_map}) and $resize ) {
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}),polarity=>'positive');
					$GEN->selCopyOther(target_layer=>$tmp_copper,invert=>'yes',size=>$resize*2000)if ( $GEN->getSelectCount() > 0 );
				}
				if( $matrix{$layer}{tl_type} =~ /(inner|dip)/ ){
					if ( $GEN->isLayerExists(job=>$Job,layer=>$PAR->{array_map_tmp}) and $resize ) {
						$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map_tmp}],clear_before=>'yes');
						$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}),polarity=>'positive');
						$GEN->selCopyOther(target_layer=>$tmp_copper,invert=>'yes',size=>$resize*2000)if ( $GEN->getSelectCount() > 0 );
					}
				}
				else{
					$GEN->affectedLayer(affected=>'yes',layer=>[$layer],clear_before=>'yes');
					$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}),polarity=>'positive');
					$GEN->selCopyOther(target_layer=>$tmp_copper,invert=>'yes',size=>$resize*2000)if ( $GEN->getSelectCount() > 0 );
				}
			}
			##tooling孔避铜
			if( $MAP{map_tooling_hole_exist} or $MAP{tmp_tooling_hole_exist} ){
				if ( $GEN->isLayerExists(job=>$Job,layer=>$PAR->{array_map}) and $info{fill_copper}{$layer}{fill_to_hole} ) {
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}),polarity=>'positive');
					$GEN->selCopyOther(target_layer=>$tmp_copper,invert=>'yes',size=>$info{fill_copper}{$layer}{fill_to_hole}*2000||0)if ( $GEN->getSelectCount() > 0 );
				}
				#if($MAP{drills}){
				#	$GEN->affectedLayer(affected=>'yes',layer=>[@{$MAP{drills}}],clear_before=>'yes');
				#	$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}),polarity=>'positive');
				#	$GEN->selectByFilter(attribute=>[{attribute=>'.drill',option=>'non_plated'}],polarity=>'positive');
				#	$GEN->selCopyOther(target_layer=>$tmp_copper,invert=>'yes',size=>$info{fill_copper}{$layer}{fill_to_hole}*2000||0)if ( $GEN->getSelectCount() > 0 );
				#}
				if ( $GEN->isLayerExists(job=>$Job,layer=>$PAR->{array_map_tmp}) and $info{fill_copper}{$layer}{fill_to_hole} ) {
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map_tmp}],clear_before=>'yes');
					$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}),polarity=>'positive');
					$GEN->selectByFilter(attribute=>[{attribute=>'.drill',option=>'non_plated'}],polarity=>'positive');
					$GEN->selCopyOther(target_layer=>$tmp_copper,invert=>'yes',size=>$info{fill_copper}{$layer}{fill_to_hole}*2000||0)if ( $GEN->getSelectCount() > 0 );
				}
			}
			##其他物件避铜
			if( $MAP{map_other_exist} or $MAP{$layer}{other_exist} and $info{fill_copper}{$layer}{fill_to_other} ){
				my $tmp_contourize = 'tmp_contourize_';
				$GEN->deleteLayer(job=>$Job,layer=>[$tmp_contourize],step=>$par{step});
				if ( $GEN->isLayerExists(job=>$Job,layer=>$PAR->{array_map}) ) {
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					$GEN->COM('sel_all_feat');
					$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}),operation=>'unselect')if( $PAR->{fiducial_attribute} );
					$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}),operation=>'unselect')if( $PAR->{tooling_hole_attribute} );
					$GEN->selectByFilter(attribute=>eval($PAR->{pn_attribute}),operation=>'unselect')if( $PAR->{pn_attribute} );
					$GEN->selectByFilter(attribute=>[{attribute=>'tl_string',text=>'*'}],operation=>'unselect');
					if( $GEN->getSelectCount() >0 ){
						$GEN->selCopyOther(target_layer=>$tmp_contourize,invert=>'no');
						$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_contourize],clear_before=>'yes');
						$GEN->selContourize();
						$GEN->selMoveOther(target_layer=>$tmp_copper,invert=>'yes',size=>$info{fill_copper}{$layer}{fill_to_other}*2000||0);
					}
				}
				$GEN->affectedLayer(affected=>'yes',layer=>[$layer],clear_before=>'yes');
				$GEN->COM('sel_all_feat');
				$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}),operation=>'unselect')if( $PAR->{fiducial_attribute} );
				$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}),operation=>'unselect')if( $PAR->{tooling_hole_attribute} );
				#$GEN->selectByFilter(attribute=>eval($PAR->{pn_attribute}),operation=>'unselect')if( $PAR->{pn_attribute} );
				$GEN->selectByFilter(attribute=>[{attribute=>'tl_string',text=>'*'}],operation=>'unselect');
				if( $GEN->getSelectCount() >0 ){
					$GEN->selCopyOther(target_layer=>$tmp_contourize,invert=>'no');
					$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_contourize],clear_before=>'yes');
					$GEN->selContourize();
					$GEN->selMoveOther(target_layer=>$tmp_copper,invert=>'yes',size=>$info{fill_copper}{$layer}{fill_to_other}*2000||0);
				}
				$GEN->deleteLayer(job=>$Job,layer=>[$tmp_contourize],step=>$par{step});
			}
			$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_copper],clear_before=>'yes');
			$GEN->selContourize();
			$GEN->selFill(solid_type=>'fill',min_brush=>$PAR->{units} eq 'inch' ? 5 : 127);
			$GEN->selContourize();
			##铺网格
			$GEN->workLayer(name=>$tmp_copper,display_number=>1,clear_before=>'yes');
			$GEN->displayLayer(name=>$layer,number=>2);
			update_loading("请确认$layer 层铺铜是否需手动优化，",0,position=>'n');
			my $ans = $GEN->PAUSE('Please Check');
			return 'Cancel' unless $ans eq 'OK';
			
			if( $info{fill_copper}{$layer}{fill_type} eq 'cross' ){
				my $std_indent = 'odd';
				$std_indent = 'even' unless $matrix{$layer}{tl_num}%2;
				$GEN->selFill(type=>'standard',std_type=>'cross',std_line_width=>$info{cross_line}*1000,std_step_dist=>$info{cross_space}*1000,std_indent=>$std_indent,outline_draw=>'yes',outline_width=>$info{cross_outline}*1000);
			}
			
			##外层添加
			if( $matrix{$layer}{tl_type} =~ /(outer)/ ){
				##光学点
				if( $info{fid_add_layer} and grep{$_ eq 'outer'} @{$info{fid_add_layer}}){
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}));
					if ( $GEN->getSelectCount() > 0 ){
						$GEN->selCopyOther(target_layer=>$tmp_copper,invert=>'no');
						$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_copper],clear_before=>'yes');
						$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}));
						#my $new_symbol = 'r'.$info{fid_outer}*1000;
						$GEN->selChangeSym(symbol=>$info{fid_outer})if ( $GEN->getSelectCount() > 0 );
					}
				}
				##料号名
				if( $info{pn_add_layer} and grep{$_ eq 'outer'} @{$info{pn_add_layer}}){
					my $tmp_layer = 'pn_tmp_layer';
					my $tmp_layer_con = 'pn_tmp_layer_contourize';
					$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer,$tmp_layer_con],step=>$par{step});
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					$GEN->selectByFilter(attribute=>eval($PAR->{pn_attribute}));
					if ( $GEN->getSelectCount() > 0 ){
						$GEN->selCopyOther(target_layer=>$tmp_layer,invert=>'no');
						$GEN->copyLayer(source_job=>$Job,source_step=>$par{step},source_layer=>$tmp_layer,dest_layer=>$tmp_layer_con,mode=>'replace');
						$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer_con],clear_before=>'yes');
						$GEN->selContourize();
						##如果是bot面需mirror
						my $layer_limits = $GEN->getLayerLimits(job=>$Job,step=>$par{step},layer=>$tmp_layer_con,units=>$PAR->{units});
						$layer_limits->{xc}=$layer_limits->{xmin}+$layer_limits->{xsize}/2;
						$layer_limits->{yc}=$layer_limits->{ymin}+$layer_limits->{ysize}/2;
						if( $matrix{$layer}{side} eq 'bottom' ){
							$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer],clear_before=>'yes');
							$GEN->selTransform(mode=>'anchor',oper=>'mirror',x_anchor=>$layer_limits->{xc},y_anchor=>$layer_limits->{yc},);
						}
						#$layer_limits = $GEN->getLayerLimits(job=>$Job,step=>$par{step},layer=>$tmp_layer,units=>$PAR->{units});
						my $clearance = $info{pn_outer_space} ? $info{pn_outer_space} : $PAR->{units} eq 'inch' ? 0.02 : 0.508;
						my $surface_polarity = $info{pn_outer_polarity} eq 'positive' ? 'negative' : 'positive';
						my $text_invert = $info{pn_outer_polarity} eq 'positive' ? 'no' : 'yes';
						$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_copper],clear_before=>'yes');
						$GEN->addRectangle(x1=>$layer_limits->{xmin}-$clearance,y1=>$layer_limits->{ymin}-$clearance,x2=>$layer_limits->{xmax}+$clearance,y2=>$layer_limits->{ymax}+$clearance,polarity=>$surface_polarity);
						$GEN->copyLayer(source_job=>$Job,source_step=>$par{step},source_layer=>$tmp_layer,dest_layer=>$tmp_copper,mode=>'append',invert=>$text_invert);
						$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer,$tmp_layer_con],step=>$par{step});
					}
				}
			}
			$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_copper],clear_before=>'yes');
			$GEN->selAddAttr(attribute=>[{attribute=>'tl_string',text=>'tl_array_overlay'}]);
			$GEN->copyLayer(source_job=>$Job,source_step=>$par{step},source_layer=>$tmp_copper,dest_layer=>$layer,mode=>'append',invert=>'no');
			$GEN->deleteLayer(job=>$Job,layer=>[$tmp_copper,$tmp_outline],step=>$par{step});
		}
		else{
			if( $matrix{$layer}{layer_type} =~ /solder_mask/){
				##添加光学点
				if( $info{fid_sm} ){
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					my $tmp_layer = 'tmp_fid_add_';
					$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer],step=>$par{step});
					$GEN->selectByFilter(attribute=>eval($PAR->{fiducial_attribute}));
					if ( $GEN->getSelectCount() > 0 ){
						$GEN->selCopyOther(target_layer=>$tmp_layer,invert=>'no');
						$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer],clear_before=>'yes');
						#my $new_symbol = 'r'.$info{fid_sm}*1000;
						$GEN->selChangeSym(symbol=>$info{fid_sm});
						$GEN->selAddAttr(attribute=>[{attribute=>'tl_string',text=>'tl_array_overlay'}]);
						$GEN->selCopyOther(target_layer=>$layer,invert=>'no');
						$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer],step=>$par{step});
					}
				}
				##添加工具孔开窗
				if( $info{hole_sm} ){
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					my $tmp_layer = 'tmp_hole_add_';
					$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer],step=>$par{step});
					$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}));
					if ( $GEN->getSelectCount() > 0 ){
						$GEN->selCopyOther(target_layer=>$tmp_layer,invert=>'no');
						$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer],clear_before=>'yes');
						$GEN->selChangeSym(symbol=>$info{hole_sm});
						$GEN->selAddAttr(attribute=>[{attribute=>'tl_string',text=>'tl_array_overlay'}]);
						$GEN->selCopyOther(target_layer=>$layer,invert=>'no');
						$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer],step=>$par{step});
					}
				}
				##添加料号名
				if( $info{pn_add_layer} and grep{$_ eq 'outer'} @{$info{pn_add_layer}}){
					my $tmp_layer = 'pn_tmp_layer';
					my $tmp_layer_con = 'pn_tmp_layer_contourize';
					$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer,$tmp_layer_con],step=>$par{step});
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					$GEN->selectByFilter(attribute=>eval($PAR->{pn_attribute}));
					if ( $GEN->getSelectCount() > 0 ){
						$GEN->selCopyOther(target_layer=>$tmp_layer,invert=>'no');
						$GEN->copyLayer(source_job=>$Job,source_step=>$par{step},source_layer=>$tmp_layer,dest_layer=>$tmp_layer_con,mode=>'replace');
						$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer_con],clear_before=>'yes');
						$GEN->selContourize();
						my $layer_limits = $GEN->getLayerLimits(job=>$Job,step=>$par{step},layer=>$tmp_layer_con,units=>$PAR->{units});
						$layer_limits->{xc}=$layer_limits->{xmin}+$layer_limits->{xsize}/2;
						$layer_limits->{yc}=$layer_limits->{ymin}+$layer_limits->{ysize}/2;
						my $clearance = $info{pn_sm};
						$GEN->affectedLayer(affected=>'yes',layer=>[$layer],clear_before=>'yes');
						$GEN->addRectangle(x1=>$layer_limits->{xmin}-$clearance,y1=>$layer_limits->{ymin}-$clearance,x2=>$layer_limits->{xmax}+$clearance,y2=>$layer_limits->{ymax}+$clearance,polarity=>'positive',attributes=>[{attribute=>'tl_string',text=>'tl_array_overlay'}]);
						$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer,$tmp_layer_con],step=>$par{step});
					}
				}
				elsif( $info{pn_add_layer} and grep{$_ eq 'sm'} @{$info{pn_add_layer}}){
					my $tmp_layer = 'pn_tmp_layer';
					my $tmp_layer_con = 'pn_tmp_layer_contourize';
					$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer,$tmp_layer_con],step=>$par{step});
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					$GEN->selectByFilter(attribute=>eval($PAR->{pn_attribute}));
					if ( $GEN->getSelectCount() > 0 ){
						$GEN->selCopyOther(target_layer=>$tmp_layer,invert=>'no');
						if( $matrix{$layer}{tl_name} =~ /sm_ba/ ){
							##如果是bot面需mirror
							$GEN->copyLayer(source_job=>$Job,source_step=>$par{step},source_layer=>$tmp_layer,dest_layer=>$tmp_layer_con,mode=>'replace');
							$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer_con],clear_before=>'yes');
							$GEN->selContourize();
							my $layer_limits = $GEN->getLayerLimits(job=>$Job,step=>$par{step},layer=>$tmp_layer_con,units=>$PAR->{units});
							$layer_limits->{xc}=$layer_limits->{xmin}+$layer_limits->{xsize}/2;
							$layer_limits->{yc}=$layer_limits->{ymin}+$layer_limits->{ysize}/2;
							$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer],clear_before=>'yes');
							$GEN->selTransform(mode=>'anchor',oper=>'mirror',x_anchor=>$layer_limits->{xc},y_anchor=>$layer_limits->{yc},);
						}
						$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer],clear_before=>'yes');
						$GEN->selAddAttr(attribute=>[{attribute=>'tl_string',text=>'tl_array_overlay'}]);
						$GEN->copyLayer(source_job=>$Job,source_step=>$par{step},source_layer=>$tmp_layer,dest_layer=>$layer,mode=>'append',invert=>'no');
						$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer,$tmp_layer_con],step=>$par{step});
					}
				}
			}
			elsif( $matrix{$layer}{layer_type} =~ /silk_screen/){
				##添加料号名
				my $tmp_layer = 'pn_tmp_layer';
				my $tmp_layer_con = 'pn_tmp_layer_contourize';
				$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer,$tmp_layer_con],step=>$par{step});
				if ( $GEN->isLayerExists(job=>$Job,layer=>$PAR->{array_map}) ) {
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					$GEN->selectByFilter(attribute=>eval($PAR->{pn_attribute}));
					if ( $GEN->getSelectCount() > 0 ){
						$GEN->selCopyOther(target_layer=>$tmp_layer,invert=>'no');
						if( $matrix{$layer}{tl_name} =~ /ss_ba/ ){
							$GEN->copyLayer(source_job=>$Job,source_step=>$par{step},source_layer=>$tmp_layer,dest_layer=>$tmp_layer_con,mode=>'replace');
							$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer_con],clear_before=>'yes');
							$GEN->selContourize();
							##如果是bot面需mirror
							my $layer_limits = $GEN->getLayerLimits(job=>$Job,step=>$par{step},layer=>$tmp_layer_con,units=>$PAR->{units});
							$layer_limits->{xc}=$layer_limits->{xmin}+$layer_limits->{xsize}/2;
							$layer_limits->{yc}=$layer_limits->{ymin}+$layer_limits->{ysize}/2;
							$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer],clear_before=>'yes');
							$GEN->selTransform(mode=>'anchor',oper=>'mirror',x_anchor=>$layer_limits->{xc},y_anchor=>$layer_limits->{yc},);
							$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer_con],step=>$par{step});
						}
						$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_layer],clear_before=>'yes');
						$GEN->selAddAttr(attribute=>[{attribute=>'tl_string',text=>'tl_array_overlay'}]);
						$GEN->copyLayer(source_job=>$Job,source_step=>$par{step},source_layer=>$tmp_layer,dest_layer=>$layer,mode=>'append',invert=>'no');
						$GEN->deleteLayer(job=>$Job,layer=>[$tmp_layer],step=>$par{step});
					}
				}
			}
			elsif( $matrix{$layer}{layer_type} =~ /drill/){
				if ( $GEN->isLayerExists(job=>$Job,layer=>$PAR->{array_map}) ) {
					$GEN->affectedLayer(affected=>'yes',layer=>[$PAR->{array_map}],clear_before=>'yes');
					my $tmp_drill = 'tmp_drill_';
					$GEN->deleteLayer(job=>$Job,layer=>[$tmp_drill],step=>$par{step});
					$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}));
					if ( $GEN->getSelectCount() > 0 ){
						$GEN->selCopyOther(target_layer=>$tmp_drill,invert=>'no')if ( $GEN->getSelectCount() > 0 );
						$GEN->affectedLayer(affected=>'yes',layer=>[$tmp_drill],clear_before=>'yes');
						#my $new_symbol = 'r'.$info{hole_drill}*1000;
						$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}));
						$GEN->selChangeSym(symbol=>$info{hole_drill})if ( $GEN->getSelectCount() > 0 );
						#$GEN->selectByFilter(attribute=>eval($PAR->{tooling_hole_attribute}));
						$GEN->selAddAttr(attribute=>[{attribute=>'tl_string',text=>'tl_array_overlay'}]);
						$GEN->selCopyOther(target_layer=>$layer,invert=>'no');
						$GEN->deleteLayer(job=>$Job,layer=>[$tmp_drill],step=>$par{step});
					}
				}
			}
		}
	}
}

__END__

