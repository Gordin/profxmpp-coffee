connection = null

on_info = (iq, elem) ->
    # do nothing if the response is not for the selected branch
    if $('.selected').length > 0 and elem isnt $('.selected')[0]
        return

    $('#feature-list').empty()
    $(iq).find("feature").each ->
        $('#feature-list').append "<li>#{$(this).attr('var')}</li>"

    $('#identity-list').empty()
    $(iq).find("identity").each ->
        cur = $(this)
        $('#identity-list').append("<li><dl><dt>Name</dt><dd>" +
                                   (cur.attr('name') || "none") +
                                   "</dd><dt>Type</dt><dd>" +
                                   (cur.attr('type') || "none") +
                                   "</dd><dt>Category</dt><dd>" +
                                   (cur.attr('category') || "none") +
                                   "</dd></dl></li>")

on_items = (iq, elem) ->
    items = $(iq).find "item"
    if items.length > 0
        $(elem).parent().append("<ul></ul>")

        list = $(elem).parent().find "ul"

        $(iq).find("item").each ->
            node = $(this).attr 'node'
            list.append("<li><span class='item'>" +
                        $(this).attr("jid") +
                        (if node then ":#{node}" else "") +
                        "</span></li>")

$(document).bind 'connect', (ev, data) ->
    conn = new Strophe.Connection(
        'http://bosh.metajack.im:5280/xmpp-httpbind')
    conn.connect data.jid, data.password, (status) ->
        if status is Strophe.Status.CONNECTED
            $(document).trigger 'connected'
        else if status is Strophe.Status.DISCONNECTED
            $(document).trigger 'disconnected'
    connection = conn;

$(document).bind 'connected', ->
    $('#dig').removeAttr 'disabled'


jQuery ->
    $('#login_dialog').dialog(
        autoOpen: true
        draggable: false
        modal: true
        title: 'Connect to XMPP'
        buttons:
            "Connect": ->
                $(document).trigger(
                    'connect'
                    jid: $('#jid').val()
                    password: $('#password').val()
                    )
                $('#password').val ''
                $(this).dialog 'close'
    )

    $('#dig').click ->
        service = $('#service').val()
        $('#service').val ''

        # set up disco info pane
        $('#selected-name').text service
        $('#identity-list').empty()
        $('#feature-list').empty()

        # clear tree pane
        $('#tree').empty()

        $('#tree').append "<li><span class='item selected'>#{service}</span></li>"

        connection.sendIQ(
            $iq(
                to   : service
                type : "get"
            ).c(
                "query"
                xmlns: "http://jabber.org/protocol/disco#info"
            )
            (iq) -> on_info iq, $('.selected')[0]
        )

        connection.sendIQ(
            $iq(
                to   : service
                type : "get"
            ).c(
                "query"
                xmlns: "http://jabber.org/protocol/disco#items"
            )
            (iq) -> on_items iq, $('.selected')[0]
        )

    $('#tree .item').live 'click', ->
        if $(this).hasClass "selected"
            $(this).removeClass "selected"
            $(this).parent().find("ul").remove()
            return

        $(".selected").removeClass "selected"
        $(this).addClass "selected"

        serv_node = $(this).text()
        idx       = serv_node.indexOf ":"
        if idx < 0
            service = serv_node
        else
            service = serv_node.slice 0, idx
            node    = serv_node.slice idx + 1

        query_attrs = if node? then node : node else {}

        elem = this;
        query_attrs["xmlns"] = "http://jabber.org/protocol/disco#info"
        connection.sendIQ(
            $iq(
                to   : service
                type : "get")
                .c(
                    "query"
                    query_attrs)
            (iq) ->
                on_info iq, elem
        )

        if $(".selected").parent().find("ul").length is 0
            query_attrs["xmlns"] = "http://jabber.org/protocol/disco#items"
            connection.sendIQ(
                $iq(
                    to: service
                    type: "get")
                    .c(
                        "query"
                        query_attrs)
                (iq) ->
                    on_items iq, elem
            )

