import React, { useContext } from 'react';
import { PatientContext } from '../../contexts/PatientContext';
import './PatientView.css';

function PatientView() {
  const { selectedPatient } = useContext(PatientContext);

  if (!selectedPatient) {
    return (
      <div className="patient-view-container">
        <h2>Detalhes do Paciente</h2> {/* Patient Details */}
        <p>Selecione um paciente para ver os detalhes.</p> {/* Select a patient to view their details. */}
      </div>
    );
  }

  // Helper to display multi-line text fields
  const renderMultiLineText = (text) => {
    if (!text) return null; // Handle cases where text might be undefined or null
    return text.split('\n').map((line, index) => (
      <React.Fragment key={index}>
        {line}
        <br />
      </React.Fragment>
    ));
  };

  return (
    <div className="patient-view-container">
      <h2>Detalhes do Paciente: {selectedPatient.name}</h2> {/* Patient Details: */}
      <div className="patient-info-section">
        <h3>Informações Básicas</h3> {/* Basic Information */}
        <p><strong>Data de Nascimento:</strong> {selectedPatient.dateOfBirth}</p> {/* Date of Birth: */}
      </div>
      <div className="patient-info-section">
        <h3>Histórico Médico:</h3> {/* Medical History */}
        <p>{renderMultiLineText(selectedPatient.medicalHistory)}</p>
      </div>
      <div className="patient-info-section">
        <h3>Medicamentos:</h3> {/* Medications */}
        <p>{renderMultiLineText(selectedPatient.medications)}</p>
      </div>
      <div className="patient-info-section">
        <h3>Resultados de Exames:</h3> {/* Lab Results */}
        <p>{renderMultiLineText(selectedPatient.labResults)}</p>
      </div>
      <div className="patient-info-section">
        <h3>Notas de Evolução:</h3> {/* Evolution Notes */}
        <p>{renderMultiLineText(selectedPatient.evolutionNotes)}</p>
      </div>
    </div>
  );
}

export default PatientView;
