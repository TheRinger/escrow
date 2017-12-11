module.exports = {
    networks: {
        main: {
            host: "localhost",
            port: 8645,
            network_id: "1" // Main network_id
        },
        development: {
            host: "localhost",
            port: 8645,
            network_id: "*" // Match any network id
        }
    }
};
