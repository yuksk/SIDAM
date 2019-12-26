$(function(){
	//	ブラウザの言語設定が日本語ならば、日本語の内容を表示する
	var isJa = ((navigator.browserLanguage || navigator.language || navigator.userLanguage).substr(0,2) == 'ja') ? true : false;
	if (isJa) $('link:eq(1)').attr('href', 'cmdlist.ja.css');
	
	//	言語切り替えリンクの設定
	$('#language > span').click(function() { 
		$('link:eq(1)').attr('href', 'cmdlist.'+$(this).attr('lang')+'.css');
	});
	
	//	ぶら下げインデントの設定
	$('dd').each(function(){
		if (this.className == 'description') return;
		var width = $(this).children('span.param').width();
		$(this).css({
			'padding-left': width + 5,
			'text-indent': -width - 5
		});
	});
});