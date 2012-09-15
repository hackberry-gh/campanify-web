// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require bootstrap
//= require bootstrap-modal-responsive-fix

$(document).ready(function(){
	
	$.errorList = function(responseText) {
		var errorList = $('<ul />');
		$.each($.parseJSON(responseText).errors, function(field,errors){
			errorList.append('<li>' + field + ' ' + errors.join(", ") + '</li>');
		});
		errorList.prepend($("<h4>Please correct erros below</h4>"));
		return errorList.html();
	}
	
	$("#my_campaigns").click( function () {
		$.get("/api/campaigns", function (data) {
			
			var campaigns_table = $("#campaigns_template_table").html(),
					campaigns_tr = $("#campaigns_template_tr").html(),
					modal = $("#my_campaigns_modal"),
					list = '';
			
			for (var i in data) {
				var campaign = data[i],
						campaign_class = campaign.status == "online" ? "success" : "warning";
				list += campaigns_tr.
								replace(/\${slug}/g, campaign.slug).
								replace(/\${name}/g, campaign.name).
								replace(/\${plan}/g, campaign.plan).
								replace(/\${status}/g, campaign.status).
								replace(/\${id}/g, campaign.id);
			}
			
			campaigns_table = campaigns_table.replace(/\${list}/, list );
			if (data.length == 0) campaigns_table = "<p>No apps found</p>"; 
			
			modal.find(".modal-body").html(campaigns_table);
			$(".campaign_class").each(function(){
				if ($(this).find(".status").text() != "online") $(this).find(".actions").html('');
				$(this).find(".change_campaign_plan").val($(this).find(".plan").text());
			});
			modal.modal();
			
			$(".change_campaign_plan").change(function(){
				var plan = $(this).val();
				var id = $(this).data("id");		
				$.post("/api/campaigns/" + id,{_method: "PUT", campaign: {plan: plan}}, function(data){
					if(data.id){
						modal.find('.close').click();
					}else{
						console.log(data);
					}
				});
			});
		
			$("a.destroy").
			on('ajax:beforeSend', function(event, data, status) {
				var a = $(this);
				a.data("text", a.text()).attr('disabled',true).text('...');
			}).
			on('ajax:error', function(event, xhr, status) {

				var a = $(this);
				$("body").prepend($("#campaigns_template_error").html().
									replace(/\${message}/, $.errorList(xhr.responseText)));
				a.removeAttr('disabled').text(a.data('val'));
			}).
			on("ajax:success", function(event, data, status) {
				console.log($(this))
				var tr = $(this).parents("tr");
				tr.fadeOut(function () { tr.remove() });
			});
		})
	});
	
	$("form[data-remote=true]").
	on('ajax:beforeSend', function(event, data, status) {
		
		var submit = $(this).find("input[type=submit]");
		submit.data("val", submit.val()).attr('disabled',true).val('...');
	}).
	on('ajax:error', function(event, xhr, status) {
		
		var submit = $(this).find("input[type=submit]");
		$("body").prepend($("#campaigns_template_error").html().
							replace(/\${message}/, $.errorList(xhr.responseText)));
		submit.removeAttr('disabled').val(submit.data('val'));
	}).
	on("ajax:success", function(event, data, status) {
		
		var form = $(this);
		form.slideUp(function () { 
			$(this).replaceWith( $( $("#campaigns_template_success").html() ).hide().fadeIn() )
		});
	});

});