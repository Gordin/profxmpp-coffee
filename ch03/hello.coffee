Hello =
    connection    : null
    start_time    : null

    log: (msg) ->
        $('#log').append("<p>" + msg + "</p>")

    send_ping: (to) ->
        ping = $iq(
            to   : to
            type : "get"
            id   : "ping1"
        ).c(
            "ping"
            xmlns: "urn:xmpp:ping"
        )

        @log("Sending ping to #{to}.")

        @start_time = (new Date()).getTime()
        @connection.send(ping)

    handle_pong: (iq, _this = Hello) =>
        elapsed = (new Date()).getTime() - @start_time
        @log("Received pong from server in #{elapsed}ms")

        @connection.disconnect()

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
            conn = new Strophe.Connection("http://bosh.metajack.im:5280/xmpp-httpbind")
            conn.connect(
                data.jid
                data.password
                (status) ->
                    if status == Strophe.Status.CONNECTED
                        $(document).trigger('connected')
                    else if status == Strophe.Status.DISCONNECTED
                        $(document).trigger('disconnected')
            )
            Hello.connection = conn
    )

    $(document).bind(
        'connected'
        ->
            # inform the user
            Hello.log "Connection established."

            Hello.connection.addHandler(
                Hello.handle_pong
                null, "iq", null, "ping1"
            )

            domain = Strophe.getDomainFromJid(Hello.connection.jid)

            Hello.send_ping(domain)
    )

    $(document).bind(
        'disconnected'
        ->
            Hello.log "Connection terminated."

            # remove dead connection object
            Hello.connection = null
    )
