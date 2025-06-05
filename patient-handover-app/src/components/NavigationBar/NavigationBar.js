import React from 'react';
import { Link } from 'react-router-dom';
import './NavigationBar.css';

function NavigationBar() {
  return (
    <nav className="navigation-bar">
      {/* Assuming "Patient Handover App" is the app title, implied by the bar itself or a logo.
          If there was a specific text element for the app title, it would be here.
          For example: <div className="app-title">Controle de Pacientes</div> */}
      <ul>
        <li><Link to="/">Início</Link></li> {/* Home */}
        <li><Link to="/add-patient">Adicionar Novo Paciente</Link></li> {/* Add Patient */}
      </ul>
    </nav>
  );
}

export default NavigationBar;
