Peek =
    connection : null

    show_traffic: (body, type) ->
        if body.childNodes.length > 0
            console = $('#console').get(0)
            at_bottom =
                console.scrollTop >= console.scrollHeight - console.clientHeight

            $.each body.childNodes, ->
                $('#console').append(
                    "<div class='#{type}'>" +
                    Peek.xml2html(Strophe.serialize(this)) +
                    "</div>"
                )

            if at_bottom
                console.scrollTop = console.scrollHeight

    xml2html: (s) ->
        s.replace(/&/g, "&amp;")
         .replace(/</g, "&lt;")
         .replace(/>/g, "&gt;")

jQuery ->

    $('#login_dialog').dialog(
        autoOpen  : yes
        draggable : no
        modal     : yes
        title     : 'Connect to XMPP'
        buttons:
            "Connect": ->
                $(document).trigger(
                    'connect'
                    jid      : $('#jid').val()
                    password : $('#password').val()
                    )
                $('#password').val('')
                $(this).dialog('close')
    )

    $(document).bind(
        'connect'
        (ev, data) ->
            conn = new Strophe.Connection(
                "http://bosh.metajack.im:5280/xmpp-httpbind")

            conn.xmlInput  = (body) -> Peek.show_traffic(body, 'incoming')
            conn.xmlOutput = (body) -> Peek.show_traffic(body, 'outgoing')

            conn.connect(
                data.jid
                data.password
                (status) ->
                    if status == Strophe.Status.CONNECTED
                        $(document).trigger('connected')
                    else if status == Strophe.Status.DISCONNECTED
                        $(document).trigger('disconnected')
            )
            Peek.connection = conn
    )

    $(document).bind(
        'connected'
        -> $('#disconnect_button').removeAttr 'disabled'
    )

    $(document).bind(
        'disconnected'
        -> $('#disconnect_button').attr 'disabled', 'disabled'
    )

    $('#disconnect_button').click -> Peek.connection.disconnect()
